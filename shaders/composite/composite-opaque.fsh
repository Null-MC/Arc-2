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

#ifdef SHADOWS_ENABLED
    uniform sampler2D TEX_SHADOW;
#endif

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

    #ifdef EFFECT_SSAO_ENABLED
        uniform sampler2D texAccumOcclusion_opaque;
        uniform sampler2D texAccumOcclusion_opaque_alt;
    #endif
#elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#endif

#if LIGHTING_MODE == LIGHT_MODE_LPV
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/buffers/sh-gi.glsl"
#endif

#include "/lib/sampling/erp.glsl"
#include "/lib/sampling/depth.glsl"
#include "/lib/hg.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/material_fresnel.glsl"
#include "/lib/material/wetness.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/light/sampling.glsl"
#include "/lib/light/volumetric.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/transmittance.glsl"

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    #include "/lib/effects/ssr.glsl"
#endif

#ifdef VOXEL_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_LPV
    #include "/lib/lpv/floodfill.glsl"
#endif

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
    #include "/lib/sky/clouds.glsl"
    #include "/lib/shadow/clouds.glsl"
#endif

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/lpv/sh-gi-sample.glsl"
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

        #ifdef ACCUM_ENABLED
            bool altFrame = (ap.time.frames % 2) == 1;
        #endif

        albedo.rgb = RgbToLinear(albedo.rgb);

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
        float porosity = data_b.a;

        bool is_trans_fluid = iris_hasFluid(trans_blockId);

        float wetness = ap.camera.fluid == 1
            ? step(depthOpaque, depthTrans)
            : step(depthTrans, depthOpaque-EPSILON) * float(is_trans_fluid);

        float sky_wetness = smoothstep(0.9, 1.0, lmCoord.y) * ap.world.rain;
        wetness = max(wetness, sky_wetness);

        bool isWet = ap.camera.fluid == 1
            ? (depthTrans >= depthOpaque)
            : (depthTrans < depthOpaque && is_trans_fluid);

        //lmCoord = _pow3(lmCoord);

        float roughL = _pow2(roughness);

        ApplyWetness_roughL(roughL, wetness);
        roughness = sqrt(roughL);

        vec3 H = normalize(Scene_LocalLightDir + -localViewDir);

        float NoLm = max(dot(localTexNormal, Scene_LocalLightDir), 0.0);
        float LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);

        vec4 shadow_sss = vec4(vec3(1.0), 0.0);
        #ifdef SHADOWS_ENABLED
            shadow_sss = textureLod(TEX_SHADOW, uv, 0);
        #endif

        float skyLightF = smoothstep(0.0, 0.2, Scene_LocalLightDir.y);

        #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
            skyLightF *= SampleCloudShadows(localPos);
        #endif

        #if defined(EFFECT_SSAO_ENABLED) || defined(EFFECT_SSGI_ENABLED)
            vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
        #endif

        float occlusion = texOcclusion;

        #ifdef EFFECT_SSAO_ENABLED //&& !defined ACCUM_ENABLED
            #ifdef ACCUM_ENABLED
                float ssao_occlusion;
                if (altFrame) ssao_occlusion = textureLod(texAccumOcclusion_opaque_alt, uv, 0).r;
                else ssao_occlusion = textureLod(texAccumOcclusion_opaque, uv, 0).r;
            #else
                float ssao_occlusion = gi_ao.a;
            #endif

            occlusion *= ssao_occlusion;
        #endif

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);
        vec3 sunLight = skyLightF * SUN_LUX * sunTransmit;
        vec3 moonLight = skyLightF * MOON_LUX * moonTransmit;

        float NoL_sun = dot(localTexNormal, Scene_LocalSunDir);
        float NoL_moon = -NoL_sun;

        #ifdef VL_SELF_SHADOW
            #ifdef EFFECT_TAA_ENABLED
                float shadow_dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
            #else
                float shadow_dither = InterleavedGradientNoise(gl_FragCoord.xy);
            #endif

            float shadowStepDist = 1.0;
            float shadowDensity = 0.0;
            for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
                vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + localPos;

                float shadowSampleDensity = VL_WaterDensity;
                if (ap.camera.fluid != 1) {
                    shadowSampleDensity = GetSkyDensity(fogShadow_localPos);

                    #ifdef SKY_FOG_NOISE
                        shadowSampleDensity += SampleFogNoise(fogShadow_localPos);
                    #endif
                }

                shadowDensity += shadowSampleDensity * shadowStepDist;// * (1.0 - max(1.0 - ii, 0.0));
                shadowStepDist *= 2.0;
            }

            if (shadowDensity > 0.0) {
                float transmittance = exp(-VL_ShadowTransmit * shadowDensity);
                sunLight *= transmittance;
                moonLight *= transmittance;
            }
        #endif

        vec3 skyLight_NoLm = sunLight * max(NoL_sun, 0.0) + moonLight * max(NoL_moon, 0.0);

        vec3 skyLightDiffuse = skyLight_NoLm * shadow_sss.rgb * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        // SSS
        const float sss_G = 0.24;

        vec2 sss_skyIrradianceCoord = DirectionToUV(localViewDir);
        vec3 sss_skyIrradiance = textureLod(texSkyIrradiance, sss_skyIrradianceCoord, 0).rgb;
        sss_skyIrradiance = (SKY_AMBIENT * lmCoord.y) * sss_skyIrradiance;

        float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
        vec3 sss_phase_sun = max(HG(VoL_sun, sss_G), 0.0) * abs(NoL_sun) * sunLight;
        vec3 sss_phase_moon = max(HG(-VoL_sun, sss_G), 0.0) * abs(NoL_moon) * moonLight;
        vec3 sss_skyLight = shadow_sss.w * (sss_phase_sun + sss_phase_moon)
                          + phaseIso * sss_skyIrradiance * occlusion;

        skyLightDiffuse = mix(skyLightDiffuse, sss_skyLight * PI, sss);

        #ifdef VOXEL_ENABLED
            vec3 voxelPos = GetVoxelPosition(localPos);
        #endif

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyIrradiance = (SKY_AMBIENT * lmCoord.y) * (skyIrradiance + Sky_MinLight);

//        #if !(defined(LIGHTING_GI_ENABLED) && defined(LIGHTING_GI_SKYLIGHT))
//            skyIrradiance *= 2.0;
//        #endif

        #ifdef LIGHTING_GI_ENABLED
            if (IsInVoxelBounds(voxelPos)) {
                #ifdef LIGHTING_GI_SKYLIGHT
                    skyIrradiance = vec3(0.0);
                #endif

                vec3 voxelSamplePos = 0.5*localGeoNormal + voxelPos;
                skyIrradiance += sample_sh_gi_linear(voxelSamplePos, localTexNormal);
            }
        #endif

        skyLightDiffuse += skyIrradiance;
        skyLightDiffuse *= occlusion;

        #if defined EFFECT_SSGI_ENABLED && !defined ACCUM_ENABLED
            skyLightDiffuse += gi_ao.rgb;
        #endif

        vec3 blockLighting = blackbody(Lighting_BlockTemp) * (BLOCK_LUX * lmCoord.x) * (occlusion*0.5 + 0.5);

        #if LIGHTING_MODE == LIGHT_MODE_RT
            if (IsInVoxelBounds(voxelPos)) {
                blockLighting = vec3(0.0);
            }
        #elif LIGHTING_MODE == LIGHT_MODE_LPV
            if (IsInVoxelBounds(voxelPos)) {
                vec3 voxelSamplePos = 0.5*localTexNormal - 0.25*localGeoNormal + voxelPos;
                blockLighting = sample_floodfill(voxelSamplePos);
            }
        #endif

        vec3 diffuse = skyLightDiffuse + blockLighting + 0.0016 * occlusion;

        #ifdef ACCUM_ENABLED
            if (altFrame) diffuse += textureLod(texAccumDiffuse_opaque_alt, uv, 0).rgb;
            else diffuse += textureLod(texAccumDiffuse_opaque, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            diffuse += textureLod(texDiffuseRT, uv, 0).rgb;
        #endif

        float metalness = mat_metalness(f0_metal);
        diffuse *= 1.0 - metalness * (1.0 - roughL);

        #if MATERIAL_EMISSION_POWER != 1
            diffuse += pow(emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness * BLOCK_LUX;
        #else
            diffuse += emission * Material_EmissionBrightness * BLOCK_LUX;
        #endif

        // reflections
        #if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
            vec3 viewDir = normalize(viewPos);
            vec3 viewNormal = mat3(ap.camera.view) * localTexNormal;
            vec3 reflectViewDir = reflect(viewDir, viewNormal);
            vec3 reflectLocalDir = mat3(ap.camera.viewInv) * reflectViewDir;

            #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                randomize_reflection(reflectLocalDir, localTexNormal, roughness);
            #endif

            vec3 skyPos = getSkyPosition(vec3(0.0));
            vec3 skyReflectColor = lmCoord.y * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);

            vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit;
            vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit;
            skyReflectColor += shadow_sss.rgb * (reflectSun + reflectMoon);

            // vec3 starViewDir = getStarViewDir(reflectLocalDir);
            // vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);
            // skyReflectColor += starLight;
        #else
            vec3 skyReflectColor = vec3(0.0);
        #endif

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

        vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);

        float NoHm = max(dot(localTexNormal, H), 0.0);
        vec3 specular = skyLight_NoLm * shadow_sss.rgb * SampleLightSpecular(NoLm, NoHm, LoHm, roughL);

        specular += skyReflectColor;

        #ifdef ACCUM_ENABLED
            if (altFrame) specular += textureLod(texAccumSpecular_opaque_alt, uv, 0).rgb;
            else specular += textureLod(texAccumSpecular_opaque, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            specular += textureLod(texSpecularRT, uv, 0).rgb;
        #endif

        float smoothness = 1.0 - roughness;
        specular *= GetMetalTint(albedo.rgb, f0_metal) * _pow2(smoothness);

        #ifdef DEBUG_WHITE_WORLD
            albedo.rgb = WhiteWorld_Value;
        #endif

//        float wetnessDarkenF = wetness*porosity;
//        albedo.rgb *= 1.0 - 0.2*wetnessDarkenF;
//        albedo.rgb = pow(albedo.rgb, vec3(1.0 + 1.2*wetnessDarkenF));

        ApplyWetness_albedo(albedo.rgb, porosity, wetness);

        colorFinal = mix(albedo.rgb * diffuse, specular, view_F);

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }
    else {
        vec3 skyPos = getSkyPosition(vec3(0.0));
        colorFinal = getValFromSkyLUT(texSkyView, skyPos, localViewDir, Scene_LocalSunDir);

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

    colorFinal = clamp(colorFinal * 0.001, 0.0, 65000.0);

    outColor = vec4(colorFinal, 1.0);
}
