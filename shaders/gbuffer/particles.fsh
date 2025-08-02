#version 430

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

in VertexData2 {
    vec2 uv;
    vec2 light;
    vec4 color;
    vec3 localPos;
    vec3 shadowViewPos;
} vIn;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler3D texFogNoise;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowColor;
    uniform sampler2DArray texShadowBlocker;
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
    uniform samplerCubeArrayShadow pointLightFiltered;

    #ifdef LIGHTING_SHADOW_PCSS
        uniform samplerCubeArray pointLight;
    #endif
#endif

#ifdef FLOODFILL_ENABLED
    uniform sampler3D texFloodFill_final;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #include "/lib/buffers/light-list.glsl"
#endif

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/buffers/wsgi.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/sampling/erp.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/hsv.glsl"

#include "/lib/hg.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/irradiance.glsl"
#include "/lib/sky/transmittance.glsl"

#include "/lib/light/sky.glsl"
#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/volumetric.glsl"

#include "/lib/material/material.glsl"
#include "/lib/material/material_fresnel.glsl"

#include "/lib/lightmap/lmcoord.glsl"
#include "/lib/lightmap/sample.glsl"

#ifdef SHADOWS_ENABLED
    #ifdef SHADOW_DISTORTION_ENABLED
        #include "/lib/shadow/distorted.glsl"
    #endif

    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
    #include "/lib/sky/clouds.glsl"
    #include "/lib/shadow/clouds.glsl"
#endif

#ifdef VL_SELF_SHADOW
    #include "/lib/sky/density.glsl"
#endif

#include "/lib/voxel/voxel-common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #include "/lib/light/sampling.glsl"
    #include "/lib/light/meta.glsl"

    #include "/lib/shadow-point/common.glsl"
    #include "/lib/shadow-point/sample-common.glsl"
    #include "/lib/shadow-point/sample-particle.glsl"
#endif

#ifdef FLOODFILL_ENABLED
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/voxel/wsgi-common.glsl"
    #include "/lib/voxel/wsgi-sample.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vIn.light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    float mLOD = textureQueryLod(irisInt_BaseTex, mUV).y;

    vec4 albedo = iris_sampleBaseTexLod(mUV, int(mLOD));
    //if (iris_discardFragment(albedo)) {discard; return;}
    if (albedo.a < 0.1) {discard; return;}

    vec2 lmcoord = LightMapNorm(mLight);

    vec4 normalData = iris_sampleNormalMapLod(mUV, int(mLOD));
    vec4 specularData = iris_sampleSpecularMapLod(mUV, int(mLOD));

    #if MATERIAL_FORMAT != MAT_NONE
        //vec3 localTexNormal = mat_normal(normalData.xyz);
        float roughness = mat_roughness(specularData.r);
        float f0_metal = specularData.g;
        //float porosity = mat_porosity(specularData.b, roughness, f0_metal);
    #endif

    #if MATERIAL_FORMAT == MAT_LABPBR
        float emission = mat_emission_lab(specularData.a);
        //float sss = mat_sss_lab(specularData.b);
        float occlusion = normalData.z;
    #elif MATERIAL_FORMAT == MAT_OLDPBR
        float emission = specularData.b;
        float occlusion = 1.0;
        //float sss = 0.0;
    #else
        //vec3 localTexNormal = localGeoNormal;
        float occlusion = 1.0;
        float roughness = 0.92;
        float f0_metal = 0.0;
        //float porosity = 1.0;
        //float sss = 0.0;
        float emission = iris_getEmission(vIn.blockId) / 15.0;
    #endif

    float roughL = _pow2(roughness);

     albedo *= mColor;
     albedo.rgb = RgbToLinear(albedo.rgb);

     #ifdef DEBUG_WHITE_WORLD
         albedo.rgb = WhiteWorld_Value;
     #endif

    vec3 shadowSample = vec3(1.0);
    #ifdef SHADOWS_ENABLED
        int shadowCascade;
        vec3 shadowPos = GetShadowSamplePos(vIn.shadowViewPos, Shadow_MaxPcfSize, shadowCascade);
        shadowSample = SampleShadowColor_PCSS(shadowPos, shadowCascade);
    #endif

    float skyLightF = smoothstep(0.0, 0.2, Scene_LocalLightDir.y);

    #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
        skyLightF *= SampleCloudShadows(vIn.localPos);
    #endif

    vec3 sunTransmit, moonTransmit;
    GetSkyLightTransmission(vIn.localPos, sunTransmit, moonTransmit);
    vec3 sunLight = SUN_LUX * sunTransmit;
    vec3 moonLight = MOON_LUX * moonTransmit;

    #ifdef VL_SELF_SHADOW
        #ifdef EFFECT_TAA_ENABLED
            float shadow_dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float shadow_dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif

        float shadowStepDist = 1.0;
        float shadowDensity = 0.0;
        for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
            vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + vIn.localPos;

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
            skyLightF *= transmittance;
        }
    #endif

    vec3 localViewDir = normalize(vIn.localPos);

    vec3 skyLightFinal = skyLightF * (sunLight + moonLight);

    vec3 skyLightDiffuse = skyLightFinal * shadowSample;// * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

    vec3 skyIrradiance = SampleSkyIrradiance(-localViewDir, lmcoord.y);
    //skyIrradiance *= mix(2.0, 1.0, skyLightF);

    #ifdef LIGHTING_GI_ENABLED
        #ifdef LIGHTING_GI_SKYLIGHT
            vec3 wsgi_bufferPos = wsgi_getBufferPosition(vIn.localPos, WSGI_CASCADE_COUNT+WSGI_SCALE_BASE-1);

            if (wsgi_isInBounds(wsgi_bufferPos))
                skyIrradiance = vec3(0.0);
        #endif

        skyIrradiance += wsgi_sample(vIn.localPos, -localViewDir);
    #endif

    skyLightDiffuse += skyIrradiance;
    skyLightDiffuse *= occlusion;

    vec3 blockLighting = GetVanillaBlockLight(lmcoord.x, occlusion);

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS || defined(FLOODFILL_ENABLED)
        vec3 voxelPos = voxel_GetBufferPosition(vIn.localPos);
    #endif

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
        if (shadowPoint_isInBounds(vIn.localPos)) {
            blockLighting = sample_AllPointLights_particle(vIn.localPos);
        }
    #endif

    #ifdef FLOODFILL_ENABLED
        if (floodfill_isInBounds(voxelPos)) {
            vec3 floodfill_light = floodfill_sample(voxelPos);

            #if LIGHTING_MODE == LIGHT_MODE_LPV
                float floodfill_FadeF = floodfill_getFade(voxelPos);
                blockLighting = mix(blockLighting, floodfill_light, floodfill_FadeF);
            #else
                blockLighting += floodfill_light;
            #endif
        }
    #endif

    //vec3 diffuse = skyLightF * (sun_light + moon_light) * shadowSample;
    vec3 diffuse = skyLightDiffuse + blockLighting;
    diffuse += World_MinAmbientLight * occlusion;

    float metalness = mat_metalness(f0_metal);
    diffuse *= 1.0 - metalness * (1.0 - roughL);

    #if MATERIAL_EMISSION_POWER != 1
        diffuse += pow(emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
    #else
        diffuse += emission * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
    #endif

    vec4 finalColor = albedo;
    finalColor.rgb *= diffuse;

    //float viewDist = length(vIn.localPos);
    //float fogF = smoothstep(fogStart, fogEnd, viewDist);
    //finalColor.rgb = mix(finalColor.rgb, fogColor.rgb, fogF);

    finalColor.rgb *= BufferLumScaleInv;
    outColor = finalColor;
}
