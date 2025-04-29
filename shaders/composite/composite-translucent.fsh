#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texFinalOpaque;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredTrans_Color;
uniform sampler2D texDeferredTrans_TexNormal;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texParticles;
uniform sampler2D texClouds;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

//uniform sampler2DArray shadowMap;
//uniform sampler2DArray solidShadowMap;
//uniform sampler2DArray texShadowColor;

#ifdef SHADOWS_ENABLED
    uniform sampler2D TEX_SHADOW;
#endif

#if defined VOXEL_WSR_ENABLED && defined RT_TRI_ENABLED
    uniform sampler2D blockAtlas;
    uniform sampler2D blockAtlasN;
    uniform sampler2D blockAtlasS;
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    uniform sampler2D texFinalPrevious;
#endif

#ifdef EFFECT_VL_ENABLED
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#endif

#ifdef ACCUM_ENABLED
    uniform sampler2D texAccumDiffuse_translucent;
    uniform sampler2D texAccumDiffuse_translucent_alt;
    uniform sampler2D texAccumSpecular_translucent;
    uniform sampler2D texAccumSpecular_translucent_alt;
#elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#endif

#ifdef LPV_ENABLED
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

//#ifdef LPV_ENABLED
//    #include "/lib/buffers/sh-lpv.glsl"
//#endif

#if defined VOXEL_WSR_ENABLED && defined RT_TRI_ENABLED
    #include "/lib/buffers/triangle-list.glsl"
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
#include "/lib/light/volumetric.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/transmittance.glsl"

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    #include "/lib/effects/ssr.glsl"
#endif

#if defined LPV_ENABLED || defined RT_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
#endif

//#ifdef SHADOWS_ENABLED
//    #include "/lib/shadow/csm.glsl"
//    #include "/lib/shadow/sample.glsl"
//#endif

#if LIGHTING_MODE == LIGHT_MODE_LPV
    //#include "/lib/lpv/lpv_common.glsl"
    //#include "/lib/lpv/lpv_sample.glsl"
    #include "/lib/lpv/floodfill.glsl"
#endif

//#if defined VOXEL_WSR_ENABLED && defined RT_TRI_ENABLED
//    #include "/lib/voxel/triangle-test.glsl"
//    #include "/lib/voxel/triangle-list.glsl"
//    #include "/lib/effects/wsr.glsl"
//#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif

#include "/lib/composite-shared.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 colorOpaque = texelFetch(texFinalOpaque, iuv, 0).rgb;
    vec4 albedo = texelFetch(texDeferredTrans_Color, iuv, 0);

    vec4 finalColor = vec4(0.0);
    bool is_fluid = false;

    if (albedo.a > EPSILON) {
        vec3 texNormalData = texelFetch(texDeferredTrans_TexNormal, iuv, 0).rgb;
        uvec4 data = texelFetch(texDeferredTrans_Data, iuv, 0);
        float depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
        float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;

        vec3 ndcPosOpaque = vec3(uv, depthOpaque) * 2.0 - 1.0;
        vec3 ndcPosTrans = vec3(uv, depthTrans) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPosOpaque);
            unjitter(ndcPosTrans);
        #endif

        vec3 viewPosOpaque = unproject(ap.camera.projectionInv, ndcPosOpaque);
        vec3 localPosOpaque = mul3(ap.camera.viewInv, viewPosOpaque);

        vec3 viewPosTrans = unproject(ap.camera.projectionInv, ndcPosTrans);
        vec3 localPosTrans = mul3(ap.camera.viewInv, viewPosTrans);

        albedo.rgb = RgbToLinear(albedo.rgb);

        #ifdef DEBUG_WHITE_WORLD
            albedo.rgb = WhiteWorld_Value;
        #endif

        vec3 localTexNormal = normalize(texNormalData * 2.0 - 1.0);

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        vec4 data_g = unpackUnorm4x8(data.g);
        float roughness = data_g.x;
        float f0_metal = data_g.y;
        float emission = data_g.z;
        float sss = data_g.w;

        vec3 data_b = unpackUnorm4x8(data.b).xyz;
        vec2 lmCoord = data_b.xy;
        float texOcclusion = data_b.b;

        uint blockId = data.a;

        lmCoord = lmCoord*lmCoord*lmCoord;
        float roughL = roughness*roughness;

        // bool isWater = bitfieldExtract(material, 6, 1) != 0;
        is_fluid = iris_hasFluid(blockId);

//        vec3 shadowSample = vec3(1.0);
//        #ifdef SHADOWS_ENABLED
//            const float shadowPixelSize = 1.0 / shadowMapResolution;
//
//            vec3 shadowViewPos = mul3(ap.celestial.view, localPosTrans);
//            const float shadowRadius = 2.0*shadowPixelSize;
//
//            int shadowCascade;
//            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);
//            shadowSample = SampleShadowColor_PCF(shadowPos, shadowCascade, vec2(shadowRadius));
//        #endif

        vec3 localViewDir = normalize(localPosTrans);

        vec3 H = normalize(Scene_LocalLightDir + -localViewDir);

        float NoLm = max(dot(localTexNormal, Scene_LocalLightDir), 0.0);
        float LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);

        // vec4 shadow_sss = vec4(vec3(1.0), 0.0);
        // #ifdef SHADOWS_ENABLED
        //     shadow_sss = textureLod(TEX_SHADOW, uv, 0);
        // #endif
        // TODO: temp hack!
        //vec4 shadow_sss = vec4(shadowSample, sss);

        vec4 shadow_sss = vec4(vec3(1.0), 0.0);
        #ifdef SHADOWS_ENABLED
            shadow_sss = textureLod(TEX_SHADOW, uv, 0);
        #endif

        float occlusion = texOcclusion;
        // #if defined EFFECT_SSAO_ENABLED //&& !defined ACCUM_ENABLED
        //     vec4 gi_ao = textureLod(TEX_SSGIAO, uv, 0);
        //     occlusion *= gi_ao.a;
        // #endif

        vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, false);

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(localPosTrans, sunTransmit, moonTransmit);

        vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;
        vec3 skyLightDiffuse = NoLm * skyLight * shadow_sss.rgb;
        skyLightDiffuse *= SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        // #if defined EFFECT_SSGI_ENABLED && !defined ACCUM_ENABLED
        //     skyLightDiffuse += gi_ao.rgb;
        // #endif

        #if defined LPV_ENABLED || defined RT_ENABLED
            vec3 voxelPos = GetVoxelPosition(localPosTrans);
        #endif

        #ifdef LPV_ENABLED
            vec3 voxelSamplePos = voxelPos - 0.25*localGeoNormal + 0.75*localTexNormal;

            skyLightDiffuse += sample_floodfill(voxelSamplePos) * PI*SampleLightDiffuse(NoVm, 1.0, 1.0, roughL);
        #endif

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLightDiffuse += (SKY_AMBIENT * lmCoord.y) * skyIrradiance;

        skyLightDiffuse *= occlusion;

        // float VoL = dot(localViewDir, Scene_LocalLightDir);
        // float sss_phase = 4.0 * max(HG(VoL, 0.16), 0.0);
        // skyLightDiffuse += skyLight * sss_phase * max(shadow_sss.w, 0.0);// * (1.0 - NoLm);

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * lmCoord.x);

        #if defined LPV_ENABLED || defined RT_ENABLED
            // TODO: make fade and not cutover!
            if (IsInVoxelBounds(voxelPos)) blockLighting = vec3(0.0);
        #endif

        vec3 diffuse = skyLightDiffuse + blockLighting + 0.0016 * occlusion;

        #ifdef ACCUM_ENABLED
            bool altFrame = (ap.time.frames % 2) == 1;
            if (altFrame) diffuse += textureLod(texAccumDiffuse_translucent_alt, uv, 0).rgb;
            else diffuse += textureLod(texAccumDiffuse_translucent, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            diffuse += textureLod(texDiffuseRT, uv, 0).rgb;
        #endif

        float metalness = mat_metalness(f0_metal);
        diffuse *= 1.0 - metalness * (1.0 - roughL);

        #if MATERIAL_EMISSION_POWER != 1
            diffuse += pow(emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness;
        #else
            diffuse += emission * Material_EmissionBrightness;
        #endif

        // reflections
        #if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
            //vec3 reflectLocalDir = reflect(localViewDir, localTexNormal);

            vec3 viewDir = normalize(viewPosTrans);
            vec3 viewNormal = mat3(ap.camera.view) * localTexNormal;
            vec3 reflectViewDir = reflect(viewDir, viewNormal);
            vec3 reflectLocalDir = mat3(ap.camera.viewInv) * reflectViewDir;

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

        float viewDist = length(localPosTrans);

        vec4 reflection = vec4(0.0);

        #if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
            //float viewDist = length(viewPosTrans);
            vec3 reflectLocalPos = fma(reflectLocalDir, vec3(0.5*viewDist), localPosTrans);

            vec3 reflectViewStart = mul3(ap.temporal.view, localPosTrans);
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

        vec3 specular = skyLight * shadow_sss.rgb * SampleLightSpecular(NoLm, NoHm, LoHm, view_F, roughL);
        specular += view_F * skyReflectColor * reflectTint * (1.0 - roughness);

        #ifdef ACCUM_ENABLED
            if (altFrame) specular += textureLod(texAccumSpecular_translucent_alt, uv, 0).rgb;
            else specular += textureLod(texAccumSpecular_translucent, uv, 0).rgb;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            specular += textureLod(texSpecularRT, uv, 0).rgb;
        #endif

        finalColor.a = albedo.a;
        if (is_fluid) finalColor.a = 0.0;

        finalColor.rgb = albedo.rgb * diffuse * albedo.a + specular;
        //finalColor.a = min(finalColor.a + maxOf(specular), 1.0);

        // Refraction
        vec3 refractSurfaceNormal = localTexNormal;
        #ifdef MATERIAL_ROUGH_REFRACT
            randomize_reflection(refractSurfaceNormal, localGeoNormal, roughness);
        #endif

        vec3 refractViewNormal = mat3(ap.camera.view) * (refractSurfaceNormal - localGeoNormal);

        const float refractEta = (IOR_AIR/IOR_WATER);
        const vec3 refractViewDir = vec3(0.0, 0.0, 1.0);
        vec3 refractDir = refract(refractViewDir, refractViewNormal, refractEta);

        float linearDist = length(localPosOpaque - localPosTrans);

        vec2 refractMax = vec2(0.2);
        refractMax.x *= ap.game.screenSize.x / ap.game.screenSize.y;
        vec2 refraction = clamp(vec2(0.025 * linearDist), -refractMax, refractMax) * refractDir.xy;

        const int REFRACTION_STEPS = 8;
        vec2 refractStep = refraction / REFRACTION_STEPS;
        vec2 refract_uv = uv;

        for (int i = 0; i < REFRACTION_STEPS; i++) {
            vec2 sample_uv = refract_uv + refractStep;
            float sample_depth = textureLod(solidDepthTex, sample_uv, 0).r;

            if (depthTrans > sample_depth) break;
            refract_uv = sample_uv;
        }

        float refractMip = 0.0;
        #ifdef MATERIAL_ROUGH_REFRACT
            // float smooth2 = 1.0 - roughness;
            // smooth2 = smooth2*smooth2;

            float viewDistOpaque = length(localPosOpaque);
            float viewDistFar = viewDistOpaque - viewDist;
            refractMip = 6.0 * pow(roughness, 0.5) * min(viewDistFar * 0.2, 1.0);
        #endif

        colorOpaque = textureLod(texFinalOpaque, refract_uv, refractMip).rgb;

        // Fog
        // float viewDist = length(localPosTrans);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // finalColor = mix(finalColor, vec4(fogColor.rgb, 1.0), fogF);

        if (is_fluid == (ap.camera.fluid != 1)) {
            colorOpaque *= exp(-WaterTintMinDist * VL_WaterTransmit);
        }

        if (!is_fluid) {
            colorOpaque *= mix(vec3(1.0), albedo.rgb, sqrt(albedo.a));
        }

//        colorFinal = mix(colorOpaque, finalColor.rgb, finalColor.a);
//        colorOpaque *= 1.0 - finalColor.a;
//        colorOpaque += finalColor.rgb;
    }

//    if (!is_fluid && ap.camera.fluid == 1) {
//        colorOpaque *= exp(-WaterTintMinDist * VL_WaterTransmit);
//    }

    vec3 colorFinal = colorOpaque;

    colorFinal *= 1.0 - finalColor.a;
    colorFinal += finalColor.rgb;

    //vec4 clouds = textureLod(texClouds, uv, 0);
    //colorFinal = mix(colorFinal, clouds.rgb, clouds.a);

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    vec4 weather = textureLod(texParticles, uv, 0);
    colorFinal = mix(colorFinal, weather.rgb, weather.a);

    if (ap.camera.fluid == 2)
        colorFinal = RgbToLinear(vec3(0.0));

    outColor = vec4(colorFinal, 1.0);
}
