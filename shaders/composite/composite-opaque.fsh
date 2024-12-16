#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler2D TEX_SHADOW;

#ifdef SSR_ENABLED
    uniform sampler2D texFinalPrevious;
#endif

#ifdef SSGIAO_ENABLED
    uniform sampler2D TEX_SSGIAO;
#endif

#ifdef EFFECT_VL_ENABLED
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#endif

#ifdef ACCUM_ENABLED
    uniform sampler2D texDiffuseAccum;
    uniform sampler2D texDiffuseAccum_alt;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/constants.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/erp.glsl"
#include "/lib/depth.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/material_fresnel.glsl"

#ifdef LPV_ENABLED
    #include "/lib/buffers/sh-lpv.glsl"
#endif

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/light/sampling.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"

#include "/lib/light/volumetric.glsl"

#ifdef SSR_ENABLED
    #include "/lib/ssr.glsl"
#endif

#ifdef LPV_ENABLED
    #include "/lib/voxel/voxel_common.glsl"

    #include "/lib/lpv/lpv_common.glsl"
    #include "/lib/lpv/lpv_sample.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void randomize_reflection(inout vec3 reflectRay, const in vec3 normal, const in float roughL) {
    #ifdef EFFECT_TAA_ENABLED
        vec3 seed = vec3(gl_FragCoord.xy, 1.0 + frameCounter);
    #else
        vec3 seed = vec3(gl_FragCoord.xy, 1.0);
    #endif

    vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
    if (dot(randomVec, normal) <= 0.0) randomVec = -randomVec;

    float roughScatterF = 0.25 * (roughL*roughL);
    reflectRay = mix(reflectRay, randomVec, roughScatterF);
    reflectRay = normalize(reflectRay);
}


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;
    vec4 albedo = texelFetch(texDeferredOpaque_Color, iuv, 0);
    vec3 colorFinal;

    float depthOpaque = 1.0;
    if (albedo.a > EPSILON) {
        depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
    }

    vec3 ndcPos = vec3(uv, depthOpaque) * 2.0 - 1.0;

    #ifdef EFFECT_TAA_ENABLED
        unjitter(ndcPos);
    #endif

    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localViewDir = normalize(localPos);

    if (albedo.a > EPSILON) {
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        uint data_trans_g = texelFetch(texDeferredTrans_Data, iuv, 0).g;

        // #ifdef SSGIAO_ENABLED
        //     vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
        // #else
        //     const vec4 gi_ao = vec4(vec3(0.0), 1.0);
        // #endif

        albedo.rgb = RgbToLinear(albedo.rgb);

        float data_trans_water = unpackUnorm4x8(data_trans_g).b;
        bool isWet = isEyeInWater == 1
            ? depthTrans >= depthOpaque
            : depthTrans < depthOpaque && data_trans_water > 0.5;

        if (isWet) albedo.rgb = pow(albedo.rgb, vec3(1.8));

        vec4 data_r = unpackUnorm4x8(data.r);
        vec3 localNormal = normalize(data_r.xyz * 2.0 - 1.0);
        int material = int(data_r.w * 255.0 + 0.5);

        vec4 data_g = unpackUnorm4x8(data.g);
        vec2 lmCoord = data_g.xy;
        lmCoord = lmCoord*lmCoord*lmCoord; //pow(lmCoord, vec2(3.0));
        // lmCoord = lmCoord*lmCoord;

        vec4 data_b = unpackUnorm4x8(data.b);
        vec3 localTexNormal = normalize(data_b.xyz * 2.0 - 1.0);
        float occlusion = data_b.a;

        vec4 data_a = unpackUnorm4x8(data.a);
        float roughness = data_a.x;
        float f0_metal = data_a.y;
        float emission = data_a.z;
        float sss = data_a.w;

        // albedo.rgb = max(localTexNormal, 0.0);

        // TODO: bitfieldExtract()
        // float sss = 0.0;//bitfieldExtract(material, 2, 1) != 0 ? 1.0 : 0.0;
        // float emission = bitfieldExtract(material, 3, 1) != 0 ? 1.0 : 0.0;
        // emission *= lmCoord.x;

        // albedo.rgb = vec3(material / 255.0);
        // albedo.rgb = vec3(emission, sss, 0.0);

        // vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);
        // float NoLm = step(0.0, dot(localLightDir, localTexNormal));

        vec3 H = normalize(Scene_LocalLightDir + -localViewDir);

        float NoLm = max(dot(localTexNormal, Scene_LocalLightDir), 0.0);
        float LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);

        NoLm = mix(NoLm, 1.0, sss);

        vec3 shadowSample = vec3(1.0);
        #ifdef SHADOWS_ENABLED
            shadowSample *= textureLod(TEX_SHADOW, uv, 0).rgb;
        #endif

        float roughL = roughness*roughness;

        vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
        // vec3 sky_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoLm, isWet);

        vec3 skyPos = getSkyPosition(localPos);
        vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
        vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
        vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;

        float worldY = localPos.y + cameraPos.y;
        float transmitF = mix(VL_Transmit, VL_RainTransmit, rainStrength);
        float lightAtmosDist = max(SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
        skyLight *= exp2(-lightAtmosDist * transmitF) * shadowSample;

        // float occlusion = 1.0;
        #if defined SSGIAO_ENABLED && !defined ACCUM_ENABLED
            vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
            occlusion *= gi_ao.a;
        #endif

        vec3 skyLightDiffuse = skyLight * NoLm * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLightDiffuse += (SKY_AMBIENT * SKY_BRIGHTNESS * lmCoord.y) * skyIrradiance * occlusion;

        #if defined SSGIAO_ENABLED && !defined ACCUM_ENABLED
            skyLightDiffuse += gi_ao.rgb;
        #endif

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * lmCoord.x);

        #ifdef LPV_ENABLED
            // vec3 voxelPos = GetVoxelPosition(localPos);
            vec3 voxelPos = GetVoxelPosition(localPos + 0.5*localTexNormal);
            // TODO: make fade and not cutover!
            if (IsInVoxelBounds(voxelPos)) blockLighting = vec3(0.0);

            // vec3 voxelPos = GetVoxelPosition(localPos + 0.5*localTexNormal);
            blockLighting += sample_lpv_linear(voxelPos, localTexNormal) * occlusion;
        #endif

        vec3 diffuse = skyLightDiffuse + blockLighting + 0.0016;

        #ifdef ACCUM_ENABLED
            bool altFrame = (frameCounter % 2) == 1;
            diffuse += textureLod(altFrame ? texDiffuseAccum_alt : texDiffuseAccum, uv, 0).rgb;
        #endif

        diffuse *= 1.0 - f0_metal * (1.0 - roughL);

        diffuse += pow(emission, 2.2) * EMISSION_BRIGHTNESS;

        // float viewDist = length(localPosTrans);
        // vec3 localViewDir = localPosTrans / viewDist;

        vec3 reflectLocalDir = reflect(localViewDir, localTexNormal);

        randomize_reflection(reflectLocalDir, localTexNormal, roughness);

        skyPos = getSkyPosition(vec3(0.0));
        vec3 skyReflectColor = lmCoord.y * SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);

        vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit;
        vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit;
        skyReflectColor += shadowSample * (reflectSun + reflectMoon);

        // vec3 starViewDir = getStarViewDir(reflectLocalDir);
        // vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);
        // skyReflectColor += starLight;

        // TODO: vol-fog
        // for (int i = 0; i < 8; i++) {
        //     //
        // }

        #ifdef LPV_ENABLED
            // vec3 voxelPos = GetVoxelPosition(localPos + 0.5*localTexNormal);
            skyReflectColor += sample_lpv_linear(voxelPos, reflectLocalDir);
        #endif

        #ifdef SSR_ENABLED
            float viewDist = length(localPos);
            vec3 reflectViewDir = mat3(playerModelView) * reflectLocalDir;
            vec3 reflectViewPos = viewPos + 0.5*viewDist*reflectViewDir;
            vec3 reflectClipPos = unproject(playerProjection, reflectViewPos) * 0.5 + 0.5;

            vec3 clipPos = ndcPos * 0.5 + 0.5;
            vec3 reflectRay = normalize(reflectClipPos - clipPos);

            float maxLod = max(log2(minOf(screenSize)) - 2.0, 0.0);
            float roughMip = min(roughness * 6.0, maxLod);
            vec4 reflection = GetReflectionPosition(mainDepthTex, clipPos, reflectRay);
            vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

            skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
        #endif

        float NoHm = max(dot(localTexNormal, H), 0.0);

        vec3 reflectTint = GetMetalTint(albedo.rgb, f0_metal);

        vec3 specular = skyLight * SampleLightSpecular(NoLm, NoHm, LoHm, view_F, roughL);
        specular += view_F * skyReflectColor * reflectTint * (1.0 - roughness);

        colorFinal = albedo.rgb * diffuse + specular;

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }
    else {
        vec3 skyPos = getSkyPosition(vec3(0.0));
        colorFinal = SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, localViewDir, Scene_LocalSunDir);

        if (rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) < 0.0) {
            float sunLum = SUN_LUMINANCE * sun(localViewDir, Scene_LocalSunDir);
            float moonLum = MOON_LUMINANCE * moon(localViewDir, -Scene_LocalSunDir);

            vec3 starViewDir = getStarViewDir(localViewDir);
            vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);

            vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, localViewDir);

            colorFinal += (sunLum + moonLum + starLight) * skyTransmit;
        }
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    outColor = vec4(colorFinal, 1.0);
}
