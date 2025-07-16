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

uniform sampler2D texFinalPrevious;
uniform sampler2D texBloom;

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
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #include "/lib/buffers/light-list.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/sampling/erp.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/hsv.glsl"

#include "/lib/sky/common.glsl"
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
    #include "/lib/shadow-point/sample-vl.glsl"
#endif

#ifdef FLOODFILL_ENABLED
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vIn.light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    albedo.a *= 1.0 - smoothstep(cloudHeight - 16.0, cloudHeight + 16.0, vIn.localPos.y + ap.camera.pos.y);

    if (iris_discardFragment(albedo)) {discard; return;}

    // albedo *= mColor;
    // albedo.rgb = RgbToLinear(albedo.rgb);

    // #ifdef DEBUG_WHITE_WORLD
    //     albedo.rgb = vec3(1.0);
    // #endif

    // // float emission = (material & 8) != 0 ? 1.0 : 0.0;
    // const float emission = 0.0;

    // vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    vec2 lmcoord = LightMapNorm(mLight);
    // lmcoord = pow(lmcoord, vec2(3.0));

    // // vec3 _localNormal = normalize(localNormal);

    // vec3 skyLight = vec3(0.0);//GetSkyLight(vIn.localPos);

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

    // // vec3 skyPos = getSkyPosition(vIn.localPos);
    // // vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    // vec3 skyLighting = lmcoord.y * shadowSample * skyLight;

    // vec2 skyIrradianceCoord = DirectionToUV(vec3(0.0, 1.0, 0.0));
    // skyLighting += lmcoord.y * SKY_AMBIENT * SKY_BRIGHTNESS * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    // vec3 blockLighting = BLOCK_LUX * blackbody(Lighting_BlockTemp) * lmcoord.x;

    // vec4 finalColor = albedo;
    // finalColor.rgb *= skyLighting + blockLighting + (Material_EmissionBrightness * emission) + 0.002;

    vec4 finalColor = albedo;

    float viewDist = length(vIn.localPos);
    float lod = 6.0 / (viewDist*0.1 + 1.0);

    vec2 uv = gl_FragCoord.xy / ap.game.screenSize;
    finalColor.rgb = textureLod(texFinalPrevious, uv, lod).rgb * BufferLumScale * 0.8;
    finalColor.a = 1.0;

    finalColor.rgb += textureLod(texBloom, uv, 0).rgb * BufferLumScale * 0.02;

    vec3 localViewDir = normalize(vIn.localPos);
    float VoL_sun = dot(localViewDir, Scene_LocalSunDir);

    vec3 sunTransmit, moonTransmit;
    GetSkyLightTransmission(vIn.localPos, sunTransmit, moonTransmit);

    float sun_phase = max(HG(VoL_sun, 0.8), 0.0);
    float moon_phase = max(HG(-VoL_sun, 0.8), 0.0);
    vec3 sun_light = SUN_LUX * sunTransmit * sun_phase;
    vec3 moon_light = MOON_LUX * moonTransmit * moon_phase;

    finalColor.rgb += 0.02 * skyLightF * (sun_light + moon_light) * shadowSample;

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS || defined(FLOODFILL_ENABLED)
        vec3 voxelPos = voxel_GetBufferPosition(vIn.localPos);
    #endif

    const float occlusion = 1.0;
    vec3 blockLighting = phaseIso * GetVanillaBlockLight(lmcoord.x, occlusion);

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
        if (shadowPoint_isInBounds(vIn.localPos)) {
            const bool isInFluid = false;
            blockLighting = sample_AllPointLights_VL(vIn.localPos, isInFluid);
        }
    #endif

    #ifdef FLOODFILL_ENABLED
        if (floodfill_isInBounds(voxelPos)) {
            vec3 floodfill_light = phaseIso * floodfill_sample(voxelPos);

            #if LIGHTING_MODE == LIGHT_MODE_LPV
                float floodfill_FadeF = floodfill_getFade(voxelPos);
                blockLighting = mix(blockLighting, floodfill_light, floodfill_FadeF);
            #else
                blockLighting += floodfill_light;
            #endif
        }
    #endif

    finalColor.rgb += 0.2 * blockLighting;

    finalColor *= mColor;

    //float viewDist = length(vIn.localPos);
    //float fogF = smoothstep(fogStart, fogEnd, viewDist);
    //finalColor.rgb = mix(finalColor.rgb, fogColor.rgb, fogF);

    finalColor.rgb *= BufferLumScaleInv;
    outColor = finalColor;
}
