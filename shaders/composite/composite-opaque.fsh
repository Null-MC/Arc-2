#version 430 core
#extension GL_NV_gpu_shader5: enable

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredOpaque_Color;
uniform sampler2D texDeferredOpaque_TexNormal;
uniform usampler2D texDeferredOpaque_Data;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler3D texFogNoise;

uniform sampler2D TEX_SHADOW;

#ifdef MATERIAL_SSR_ENABLED
    uniform sampler2D texFinalPrevious;
#endif

#if defined EFFECT_SSAO_ENABLED || defined EFFECT_SSGI_ENABLED
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

#ifdef LPV_ENABLED
    #include "/lib/buffers/sh-lpv.glsl"
#endif

#include "/lib/erp.glsl"
#include "/lib/depth.glsl"
#include "/lib/hg.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/material_fresnel.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/light/sampling.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/clouds.glsl"

// #include "/lib/light/sky.glsl"
#include "/lib/light/volumetric.glsl"

#ifdef MATERIAL_SSR_ENABLED
    #include "/lib/effects/ssr.glsl"
#endif

#if defined LPV_ENABLED || defined RT_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
#endif

#ifdef LPV_ENABLED
    #include "/lib/lpv/lpv_common.glsl"
    #include "/lib/lpv/lpv_sample.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif

#include "/lib/composite-shared.glsl"


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
        vec3 texNormalData = texelFetch(texDeferredOpaque_TexNormal, iuv, 0).rgb;
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        uint trans_blockId = texelFetch(texDeferredTrans_Data, iuv, 0).a;

        // #if defined EFFECT_SSAO_ENABLED || defined EFFECT_SSGI_ENABLED
        //     vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
        // #else
        //     const vec4 gi_ao = vec4(vec3(0.0), 1.0);
        // #endif

        albedo.rgb = RgbToLinear(albedo.rgb);

        vec3 localTexNormal = normalize(texNormalData * 2.0 - 1.0);

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        vec4 data_g = unpackUnorm4x8(data.g);
        float roughness = data_g.x;
        float f0_metal = data_g.y;
        float emission = data_g.z;
        float sss = data_g.w;

        vec4 data_b = unpackUnorm4x8(data.b);
        vec2 lmCoord = data_b.rg;
        float texOcclusion = data_b.b;

        // float data_trans_water = unpackUnorm4x8(data_trans_a).b;
        bool is_trans_fluid = iris_hasFluid(trans_blockId);

        bool isWet = isEyeInWater == 1
            ? (depthTrans >= depthOpaque)
            : (depthTrans < depthOpaque && is_trans_fluid);

        if (isWet) albedo.rgb = pow(albedo.rgb, vec3(1.8));

        lmCoord = lmCoord*lmCoord*lmCoord;

        float roughL = roughness*roughness;

        vec3 H = normalize(Scene_LocalLightDir + -localViewDir);

        float NoLm = max(dot(localTexNormal, Scene_LocalLightDir), 0.0);
        float LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);

        vec4 shadow_sss = vec4(vec3(1.0), 0.0);
        #ifdef SHADOWS_ENABLED
            shadow_sss = textureLod(TEX_SHADOW, uv, 0);
        #endif

        vec3 cloudPos = (cloudHeight-cameraPos.y-localPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir + localPos + cameraPos;
        float cloudDensity = SampleCloudDensity(cloudPos);
        shadow_sss.rgb *= max(1.0 - 0.4*cloudDensity, 0.0);

        float occlusion = texOcclusion;
        #if defined EFFECT_SSAO_ENABLED //&& !defined ACCUM_ENABLED
            vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
            occlusion *= gi_ao.a;
        #endif

        vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
        // vec3 sky_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoLm, isWet);

        // vec3 skyPos = getSkyPosition(localPos);
        // vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
        // vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
        // vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;
        // vec3 skyLight = GetSkyBrightness(localPos);
        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);

        // float worldY = localPos.y + cameraPos.y;
        // float transmitF = mix(VL_Transmit, VL_RainTransmit, rainStrength);
        // float lightAtmosDist = max(SKY_SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
        // skyLight *= exp2(-lightAtmosDist * transmitF);

        vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;
        vec3 skyLightDiffuse = NoLm * skyLight * shadow_sss.rgb;
        skyLightDiffuse *= SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        #if defined EFFECT_SSGI_ENABLED && !defined ACCUM_ENABLED
            skyLightDiffuse += gi_ao.rgb;
        #endif

        #if defined LPV_ENABLED || defined RT_ENABLED
            vec3 voxelPos = GetVoxelPosition(localPos);
        #endif

        #ifdef LPV_ENABLED
            vec3 voxelSamplePos = voxelPos - 0.25*localGeoNormal + 0.75*localTexNormal;

            skyLightDiffuse += sample_lpv_linear(voxelSamplePos, localTexNormal) * SampleLightDiffuse(NoVm, 1.0, 1.0, roughL);
        #endif

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLightDiffuse += (SKY_AMBIENT * SKY_BRIGHTNESS * lmCoord.y) * skyIrradiance;

        skyLightDiffuse *= occlusion;

        float VoL = dot(localViewDir, Scene_LocalLightDir);
        float sss_phase = 4.0 * max(HG(VoL, 0.16), 0.0);
        skyLightDiffuse += skyLight * sss_phase * max(shadow_sss.w, 0.0);// * (1.0 - NoLm);

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * lmCoord.x);

        #if defined LPV_ENABLED || defined RT_ENABLED
            // TODO: make fade and not cutover!
            if (IsInVoxelBounds(voxelPos)) blockLighting = vec3(0.0);
        #endif

        vec3 diffuse = skyLightDiffuse + blockLighting + 0.0016 * occlusion;

        #ifdef ACCUM_ENABLED
            bool altFrame = (frameCounter % 2) == 1;
            diffuse += textureLod(altFrame ? texDiffuseAccum_alt : texDiffuseAccum, uv, 0).rgb;
        #endif

        diffuse *= 1.0 - f0_metal * (1.0 - roughL);
        diffuse *= occlusion * 0.5 + 0.5;

        #ifdef ACCUM_ENABLED
            // specular += textureLod(altFrame ? texSpecularAccum_alt : texSpecularAccum, uv, 0).rgb;
        #endif

        #if MATERIAL_EMISSION_POWER != 1
            diffuse += pow(emission, MATERIAL_EMISSION_POWER) * EMISSION_BRIGHTNESS;
        #else
            diffuse += emission * EMISSION_BRIGHTNESS;
        #endif

        // reflections
        vec3 reflectLocalDir = reflect(localViewDir, localTexNormal);

        #ifdef MATERIAL_ROUGH_REFLECT_NOISE
            randomize_reflection(reflectLocalDir, localTexNormal, roughness);
        #endif

        // vec3 skyReflectColor = GetSkyColor(vec3(0.0), reflectLocalDir, shadow_sss.rgb, lmCoord.y);
        vec3 skyPos = getSkyPosition(vec3(0.0));
        vec3 skyReflectColor = lmCoord.y * SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);

        vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit;
        vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit;
        skyReflectColor += shadow_sss.rgb * (reflectSun + reflectMoon);

        // vec3 starViewDir = getStarViewDir(reflectLocalDir);
        // vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);
        // skyReflectColor += starLight;

        // TODO: vol-fog
        // for (int i = 0; i < 8; i++) {
        //     //
        // }

        // #ifdef LPV_ENABLED
        //     // vec3 voxelPos = GetVoxelPosition(localPos + 0.5*localTexNormal);
        //     skyReflectColor += sample_lpv_linear(voxelPos, reflectLocalDir);
        // #endif

        #ifdef MATERIAL_SSR_ENABLED
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

        vec3 specular = skyLight * shadow_sss.rgb * SampleLightSpecular(NoLm, NoHm, LoHm, view_F, roughL);
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
            starLight *= step(sunLum + moonLum, EPSILON);

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
