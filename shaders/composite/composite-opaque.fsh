#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

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

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
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
    uniform sampler2D texAccumDiffuse_opaque;
    uniform sampler2D texAccumDiffuse_opaque_alt;
    uniform sampler2D texAccumSpecular_opaque;
    uniform sampler2D texAccumSpecular_opaque_alt;
#elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#endif

#include "/lib/common.glsl"
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
#include "/lib/material/material.glsl"
#include "/lib/material/material_fresnel.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/light/sampling.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/clouds.glsl"

#include "/lib/light/volumetric.glsl"

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    #include "/lib/effects/ssr.glsl"
#endif

#ifdef VOXEL_ENABLED
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

    vec3 ndcPos = fma(vec3(uv, depthOpaque), vec3(2.0), vec3(-1.0));

    #ifdef EFFECT_TAA_ENABLED
        unjitter(ndcPos);
    #endif

    vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

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

        #ifdef DEBUG_WHITE_WORLD
            albedo.rgb = WhiteWorld_Value;
        #endif

        vec3 localTexNormal = normalize(fma(texNormalData, vec3(2.0), vec3(-1.0)));

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(fma(data_r, vec3(2.0), vec3(-1.0)));

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

        bool isWet = ap.camera.fluid == 1
            ? (depthTrans >= depthOpaque)
            : (depthTrans < depthOpaque && is_trans_fluid);

        if (isWet) {
            albedo.rgb = pow(albedo.rgb, vec3(1.8));
            roughness = 0.08;
        }

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

        float cloudShadowF = 1.0;
        #if defined CLOUDS_ENABLED && defined SHADOWS_CLOUD_ENABLED
            vec3 worldPos = localPos + ap.camera.pos;

            vec3 cloudPos = (cloudHeight-worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir + worldPos;
            float cloudDensity = SampleCloudDensity(cloudPos);

            cloudPos = (cloudHeight2-worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir + worldPos;
            cloudDensity += SampleCloudDensity2(cloudPos);

            cloudShadowF = max(1.0 - 0.2*cloudDensity, 0.3);

            shadow_sss *= cloudShadowF;
        #endif

        float occlusion = texOcclusion;
        #if defined EFFECT_SSAO_ENABLED //&& !defined ACCUM_ENABLED
            vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
            occlusion *= gi_ao.a;
        #endif

        vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);

        // float worldY = localPos.y + ap.camera.pos.y;
        // float transmitF = mix(VL_Transmit, VL_RainTransmit, ap.world.rainStrength);
        // float lightAtmosDist = max(SKY_SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
        // skyLight *= exp2(-lightAtmosDist * transmitF);

        float NoL_sun = dot(localTexNormal, Scene_LocalSunDir);
        float NoL_moon = -NoL_sun;//dot(localTexNormal, -Scene_LocalSunDir);
//        vec3 skyLight = SUN_BRIGHTNESS * sunTransmit
//            + MOON_BRIGHTNESS * moonTransmit;

        vec3 skyLight_NoLm = SUN_BRIGHTNESS * sunTransmit * max(NoL_sun, 0.0)
            + MOON_BRIGHTNESS * moonTransmit * max(NoL_moon, 0.0);

        vec3 skyLightDiffuse = skyLight_NoLm * shadow_sss.rgb;
        skyLightDiffuse *= SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        #ifdef VOXEL_ENABLED
            vec3 voxelPos = GetVoxelPosition(localPos);
        #endif

        #ifdef LPV_ENABLED
            // vec3 voxelSamplePos = voxelPos - 0.25*localGeoNormal + 0.75*localTexNormal;
            vec3 voxelSamplePos = fma(localGeoNormal, vec3(0.5), voxelPos);
            vec3 voxelLight = sample_lpv_linear(voxelSamplePos, localTexNormal);

            skyLightDiffuse += voxelLight * cloudShadowF;// * SampleLightDiffuse(NoVm, 1.0, 1.0, roughL);
        #endif

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLightDiffuse += (SKY_AMBIENT * lmCoord.y) * skyIrradiance;

        skyLightDiffuse *= occlusion;

        #if defined EFFECT_SSGI_ENABLED && !defined ACCUM_ENABLED
            skyLightDiffuse += gi_ao.rgb;
        #endif

        float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
//        float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
        vec3 sss_phase_sun = max(HG(VoL_sun, 0.16), 0.0) * SUN_BRIGHTNESS * sunTransmit * (1.0 - max(NoL_sun, 0.0));
        vec3 sss_phase_moon = max(HG(-VoL_sun, 0.16), 0.0) * MOON_BRIGHTNESS * moonTransmit * (1.0 - max(NoL_moon, 0.0));
        skyLightDiffuse += PI * (sss_phase_sun + sss_phase_moon) * max(shadow_sss.w, 0.0) * abs(Scene_LocalLightDir.y);

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * lmCoord.x);

        #if LIGHTING_MODE != LIGHT_MODE_VANILLA
            // TODO: make fade and not cutover!
            if (IsInVoxelBounds(voxelPos)) blockLighting = vec3(0.0);
        #endif

        vec3 diffuse = skyLightDiffuse + blockLighting + 0.0016 * occlusion;

        #ifdef ACCUM_ENABLED
            bool altFrame = (ap.time.frames % 2) == 1;
            if (altFrame) diffuse += textureLod(texAccumDiffuse_opaque_alt, uv, 0).rgb;
            else diffuse += textureLod(texAccumDiffuse_opaque, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            diffuse += textureLod(texDiffuseRT, uv, 0).rgb;
        #endif

        float metalness = mat_metalness(f0_metal);
        diffuse *= 1.0 - metalness * (1.0 - roughL);

        //diffuse *= fma(occlusion, 0.5, 0.5);

        #if MATERIAL_EMISSION_POWER != 1
            diffuse += pow(emission, MATERIAL_EMISSION_POWER) * EMISSION_BRIGHTNESS;
        #else
            diffuse += emission * EMISSION_BRIGHTNESS;
        #endif

        // reflections
        #if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
            vec3 reflectLocalDir = reflect(localViewDir, localTexNormal);

            #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                randomize_reflection(reflectLocalDir, localTexNormal, roughness);
            #endif

            vec3 skyPos = getSkyPosition(vec3(0.0));
            vec3 skyReflectColor = lmCoord.y * SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);

            vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit;
            vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit;
            skyReflectColor += shadow_sss.rgb * (reflectSun + reflectMoon);

            // vec3 starViewDir = getStarViewDir(reflectLocalDir);
            // vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);
            // skyReflectColor += starLight;
        #else
            vec3 skyReflectColor = vec3(0.0);
        #endif

        // TODO: vol-fog
        // for (int i = 0; i < 8; i++) {
        //     //
        // }

        // #ifdef LPV_ENABLED
        //     // vec3 voxelPos = GetVoxelPosition(localPos + 0.5*localTexNormal);
        //     skyReflectColor += sample_lpv_linear(voxelPos, reflectLocalDir);
        // #endif

        vec4 reflection = vec4(0.0);

        #if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
            float viewDist = length(viewPos);
            vec3 reflectLocalPos = fma(reflectLocalDir, vec3(0.5*viewDist), localPos);

            vec3 reflectViewStart = mul3(ap.temporal.view, localPos);
            vec3 reflectViewEnd = mul3(ap.temporal.view, reflectLocalPos);

            vec3 reflectNdcStart = unproject(ap.temporal.projection, reflectViewStart);
            vec3 reflectNdcEnd = unproject(ap.temporal.projection, reflectViewEnd);

            vec3 reflectRay = normalize(reflectNdcEnd - reflectNdcStart);

            vec3 clipPos = fma(reflectNdcStart, vec3(0.5), vec3(0.5));
            reflection = GetReflectionPosition(mainDepthTex, clipPos, reflectRay);

            #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                float maxLod = max(log2(minOf(ap.game.screenSize)) - 2.0, 0.0);
                float screenDist = length((reflection.xy - uv) * ap.game.screenSize);
                float roughMip = min(roughness * min(log2(screenDist + 1.0), 6.0), maxLod);
            #else
                const float roughMip = 0.0;
            #endif

            vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

            skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
        #endif

        float NoHm = max(dot(localTexNormal, H), 0.0);

        vec3 reflectTint = GetMetalTint(albedo.rgb, f0_metal);

        float smoothness = 1.0 - roughness;
        vec3 specular = skyLight_NoLm * shadow_sss.rgb * SampleLightSpecular(NoLm, NoHm, LoHm, view_F, roughL);
        specular += view_F * skyReflectColor * reflectTint * (smoothness*smoothness);

        #ifdef ACCUM_ENABLED
            if (altFrame) specular += textureLod(texAccumSpecular_opaque_alt, uv, 0).rgb;
            else specular += textureLod(texAccumSpecular_opaque, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            specular += textureLod(texSpecularRT, uv, 0).rgb;
        #endif

        diffuse *= 1.0 - view_F;

        colorFinal = fma(albedo.rgb, diffuse, specular);

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
        colorFinal = fma(colorFinal, vlTransmit, vlScatter);
    #endif

    outColor = vec4(colorFinal, 1.0);
}
