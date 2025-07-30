#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;

uniform sampler3D texFogNoise;
uniform sampler2D texBlueNoise;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyMultiScatter;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowBlocker;
    uniform sampler2DArray texShadowColor;
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_VL_SHADOWS)
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

#if !defined(VOXEL_PROVIDED)
    #include "/lib/buffers/voxel-block.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
    #include "/lib/buffers/light-list.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/noise/blue.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/hsv.glsl"
#include "/lib/utility/tbn.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/voxel/voxel-common.glsl"

#ifdef SHADOWS_ENABLED
    #ifdef SHADOW_DISTORTION_ENABLED
        #include "/lib/shadow/distorted.glsl"
    #endif

    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#include "/lib/light/volumetric.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/clouds.glsl"

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
    #include "/lib/shadow/clouds.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
    #include "/lib/voxel/voxel-sample.glsl"
    #include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #include "/lib/light/fresnel.glsl"
    #include "/lib/light/sampling.glsl"
    #include "/lib/light/meta.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_VL_SHADOWS)
    #include "/lib/shadow-point/common.glsl"
    #include "/lib/shadow-point/sample-common.glsl"
    #include "/lib/shadow-point/sample-vl.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_RT && defined(LIGHTING_VL_SHADOWS)
    #include "/lib/voxel/dda.glsl"
    #include "/lib/voxel/light-trace.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_VANILLA
    #include "/lib/utility/blackbody.glsl"
    #include "/lib/lightmap/sample.glsl"
#endif

#ifdef FLOODFILL_ENABLED
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif

#include "/lib/vl-shared.glsl"

#ifdef VL_JITTER
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    //const float stepScale = 1.0 / VL_maxSamples_near;
    const int uv_scale = int(exp2(LIGHTING_VL_RES));
    vec2 viewSize = ap.game.screenSize / uv_scale;

    #ifdef VL_JITTER
        vec2 uv2 = uv;
        jitter(uv2, viewSize);
        ivec2 uv_depth = ivec2(uv2 * ap.game.screenSize);
    #else
        ivec2 uv_depth = ivec2(uv * ap.game.screenSize);
    #endif

    float depth = texelFetch(mainDepthTex, uv_depth, 0).r;

    #ifdef EFFECT_TAA_ENABLED
        //float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        float dither = sample_blueNoise(gl_FragCoord.xy).x;
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

    float len = length(localPos);
    vec3 localViewDir = localPos / len;

    vec3 waterAmbientBase = VL_WaterAmbient / VL_maxSamples_near * Scene_SkyIrradianceUp;
    bool isInFluid = ap.camera.fluid == 1;

//    if (!isInFluid && Scene_SkyFogDensityF < EPSILON) {
//        outScatter = vec3(0.0);
//        outTransmit = vec3(1.0);
//        return;
//    }

    float far = 256.0;//ap.camera.far * 0.5;

    if (depth >= 1.0 && len < far) len = far;

    float bias = len * 0.004;

    vec3 traceEnd = vec3(0.0);
//    vec3 traceEnd = max(len - bias, 0.0) * localViewDir;
//    if (len > far)
//        traceEnd = traceEnd * (far / len);

    //vec3 stepLocal = traceEnd / (VL_maxSamples_near);
    //float stepDist = length(stepLocal);

//    vec3 localViewDir = normalize(localPos);
    float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
    float phase_sun = DHG(VoL_sun, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);
    float VoL_moon = -VoL_sun;//dot(localViewDir, -Scene_LocalSunDir);
    float phase_moon = DHG(VoL_moon, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);

    float miePhase_sun = getMiePhase(VoL_sun, 0.2);
    float miePhase_moon = getMiePhase(VoL_moon, 0.2);

    #ifdef SKY_CLOUDS_ENABLED
        vec3 cloud_localPos;
        float cloudDensity, cloud_shadowSun, cloud_shadowMoon;
        vl_sampleClouds(localViewDir, cloud_localPos, cloudDensity, cloud_shadowSun, cloud_shadowMoon);
    #endif

    float renderDistSq = _pow2(ap.camera.renderDistance);

    vec3 sampleLocalPosLast = vec3(0.0);
    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    traceEnd = clamp(len - bias, 0.0, far) * localViewDir;
//    if (len > far)
//        traceEnd = traceEnd * (far / len);

    float stepDist = length(traceEnd) / VL_maxSamples_near;

    if (isInFluid || Scene_SkyFogDensityF > 0.0) {
        vec3 shadowViewStart = mul3(ap.celestial.view, vec3(0.0));
        vec3 shadowViewEnd = mul3(ap.celestial.view, traceEnd);
        //vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

        const vec3 localPosStart = vec3(0.0);

        for (int i = 0; i < VL_maxSamples_near; i++) {
            float iF = min(i + dither, VL_maxSamples_near-1);
            float stepF = saturate(iF / (VL_maxSamples_near-1));

            #if VL_STEP_POW != 100
                const float VL_StepPower = VL_STEP_POW * 0.01;
                stepF = pow(stepF, VL_StepPower);
            #endif

            //vec3 sampleLocalPos = iF * stepLocal;
            vec3 sampleLocalPos = mix(localPosStart, traceEnd, stepF);

            //float stepDist = length(sampleLocalPos - sampleLocalPosLast);

            vec2 sample_lmcoord = vec2(0.0, 1.0);
            #ifdef VOXEL_PROVIDED
                ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));

                if (isInFluid) {
                    uvec2 blockData;
                    if (blockWorldPos.y > -64 && blockWorldPos.y < 320 && lengthSq(sampleLocalPos) < renderDistSq) {
                        blockData = iris_getBlockAtPos(blockWorldPos).xy;
                    }

                    uint blockLightData = blockData.y;

                    uvec2 blockLightInt = uvec2(
                        bitfieldExtract(blockLightData,  0, 16),
                        bitfieldExtract(blockLightData, 16, 16));

                    sample_lmcoord = saturate(blockLightInt / 240.0);
                }
            #endif

            float waterDepth = EPSILON;
            vec3 shadowSample = vec3(1.0);//vec3(smoothstep(0.0, 0.6, Scene_SkyBrightnessSmooth));
            #ifdef SHADOWS_ENABLED
                const float shadowRadius = 2.0;// 0.02*shadowPixelSize;

                //vec3 shadowViewPos = fma(shadowViewStep, vec3(iF), shadowViewStart);
                vec3 shadowViewPos = mix(shadowViewStart, shadowViewEnd, stepF);

                int shadowCascade;
                vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

                if (shadowCascade >= 0) {
                    #ifdef VL_SOFT_SHADOW
                        float avg_depth = textureLod(texShadowBlocker, vec3(shadowPos.xy, shadowCascade), 0).r;
                        float blockerDistance = max(shadowPos.z - avg_depth, 0.0) * GetShadowRange(shadowCascade);
                        vec2 pixelRadius = GetPixelRadius(blockerDistance / SHADOW_PENUMBRA_SCALE, shadowCascade);
                        //pixelRadius = clamp(pixelRadius, vec2(minShadowPixelRadius), maxPixelRadius);
                        shadowPos.xy += (hash23(vec3(gl_FragCoord.xy, i + ap.time.frames)) - 0.5) * pixelRadius;
                    #endif

                    shadowSample *= SampleShadowColor(shadowPos, shadowCascade, waterDepth);
                    waterDepth = max(waterDepth, EPSILON);
                }
                else {
                    shadowSample = vec3(0.0);
                }
            #endif

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
            float skyLightF = smoothstep(0.0, 0.08, Scene_LocalLightDir.y);
            vec3 sunSkyLight = skyLightF * SUN_LUMINANCE * sunTransmit * Scene_SunColor;
            vec3 moonSkyLight = skyLightF * MOON_LUMINANCE * moonTransmit * Scene_MoonColor;

            #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
                if (sampleLocalPos.y+ap.camera.pos.y < cloudHeight)
                    shadowSample *= SampleCloudShadows(sampleLocalPos);
            #endif

            //float vs_shadowF = 1.0;
            float sampleDensity = VL_WaterDensity;
            if (!isInFluid) {
                sampleDensity = GetSkyDensity(sampleLocalPos);

                #ifdef SKY_FOG_NOISE
                    sampleDensity *= SampleFogNoise(sampleLocalPos);
                #endif

                #ifdef SKY_CLOUDS_ENABLED
                    float sampleHeightLast = sampleLocalPosLast.y + ap.camera.pos.y;
                    float sampleHeight = sampleLocalPos.y + ap.camera.pos.y;

                    // Clouds
                    if (sign(sampleHeight - cloudHeight) != sign(sampleHeightLast - cloudHeight)) {
                        sampleDensity = cloudDensity;
                        shadowSample = vec3(1.0);
                        stepDist = 10.0;

                        sunSkyLight *= cloud_shadowSun;
                        moonSkyLight *= cloud_shadowMoon;
                    }
                #endif

                #ifdef VL_SELF_SHADOW
                    float shadow_dither = dither;

                    float shadowStepDist = 1.0;
                    float shadowDensity = 0.0;
                    for (int ii = 0; ii < 8; ii++) {
                        vec3 fogShadow_localPos = (ii + shadow_dither) * shadowStepDist * Scene_LocalLightDir + sampleLocalPos;

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
                        float vs_shadowF = exp(-VL_ShadowTransmit * shadowDensity);
                        shadowSample *= vs_shadowF;
                    }
                #endif
            }
    //        else {
    //            ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));
    //            uint blockId = uint(iris_getBlockAtPos(blockWorldPos).x);
    //            if (!iris_hasFluid(blockId)) sampleDensity = 0.0;
    //        }

            vec3 sampleLit = vec3(0.0);

            #ifdef LIGHTING_VL_SHADOWS
                #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
                    vec3 blockLight = sample_AllPointLights_VL(sampleLocalPos, isInFluid);
                    sampleLit += blockLight;
                #elif LIGHTING_MODE == LIGHT_MODE_RT
                    vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);
                    ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
                    int lightBinIndex = GetLightBinIndex(lightBinPos);
                    uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                    vec3 jitter = hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;
                    //vec3 jitter = sample_blueNoise(gl_FragCoord.xy) * 0.5;
                    jitter *= Lighting_PenumbraSize;

                    #if RT_MAX_SAMPLE_COUNT > 0
                        uint maxSampleCount = clamp(binLightCount, 0u, RT_MAX_SAMPLE_COUNT);
                        float bright_scale = binLightCount / float(RT_MAX_SAMPLE_COUNT);
                    #else
                        uint maxSampleCount = clamp(binLightCount, 0u, RT_MAX_LIGHT_COUNT);
                        const float bright_scale = 1.0;
                    #endif

                    int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.time.frames)));

                    for (int i = 0; i < maxSampleCount; i++) {
                        int i2 = (i + i_offset) % int(binLightCount);

                        uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2].voxelIndex;

                        vec3 light_voxelPos = GetLightVoxelPos(light_voxelIndex);
                        light_voxelPos += 0.5 + jitter;

                        vec3 light_LocalPos = voxel_getLocalPosition(light_voxelPos);

                        uint blockId = SampleVoxelBlockLocal(light_LocalPos);

                        float lightRange = iris_getEmission(blockId);
                        vec3 lightColor = iris_getLightColor(blockId).rgb;
                        vec3 light_hsv = RgbToHsv(lightColor);
                        lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));
                        lightColor = RgbToLinear(lightColor);

                        vec3 lightVec = light_LocalPos - sampleLocalPos;
                        float lightAtt = GetLightAttenuation(lightVec, lightRange);
                        //lightAtt *= light_hsv.z;

                        vec3 lightColorAtt = BLOCK_LUX * lightAtt * lightColor;

                        vec3 lightDir = normalize(lightVec);

                        float VoL = dot(localViewDir, lightDir);
                        float phase = saturate(getMiePhase(VoL));

                        vec3 traceStart = light_voxelPos;
                        vec3 traceEnd = voxelPos;
                        float traceRange = lightRange;
                        bool traceSelf = !iris_isFullBlock(blockId);

                        vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

                        sampleLit += phase * shadow_color * lightColorAtt * bright_scale * 10.0;
                    }
                #endif
            #endif

            #ifdef FLOODFILL_ENABLED
                vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

                if (floodfill_isInBounds(voxelPos)) {
    //                #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
    //                    vec3 blockLight = floodfill_sampleCurve(voxelPos, 5.0);
    //                #else
                        vec3 blockLight = floodfill_sample(voxelPos);
    //                #endif

//                    #if LIGHTING_MODE != LIGHT_MODE_LPV
//                        blockLight *= (1.0/15.0);
//                    #endif

                    sampleLit += phaseIso * blockLight;
                }
            #endif

            #if LIGHTING_MODE == LIGHT_MODE_VANILLA
                vec3 blockLighting = GetVanillaBlockLight(sample_lmcoord.x, 1.0);
                sampleLit += phaseIso * blockLighting;
            #endif

    //        #ifdef LIGHTING_GI_ENABLED
    //            sampleLit += 2000.0;//100000.0 * sample_sh_gi(ivec3(floor(voxelPos)), localViewDir);
    //        #endif

            vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;

            //sampleLit *= 8.0;

            if (!isInFluid) {
                vec3 skyPos = getSkyPosition(sampleLocalPos);

                float mieDensity = sampleDensity + EPSILON;
                float mieScattering = mieScatteringF * mieDensity;
                float mieAbsorption = mieAbsorptionF * mieDensity;
                extinction = vec3(mieScattering + mieAbsorption);

                sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                vec3 ambient = psiMS * Scene_SkyBrightnessSmooth + VL_MinLight;

                //vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
                vec3 mieSkyLight = miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight;
                vec3 mieInScattering = mieScattering * (mieSkyLight * shadowSample + ambient + sampleLit);
                inScattering = mieInScattering;
            }
            else {
                #ifdef VOXEL_PROVIDED
                    vec3 sampleAmbient = waterAmbientBase * sample_lmcoord.y;
                #else
                    vec3 sampleAmbient = waterAmbientBase * Scene_SkyBrightnessSmooth;
                #endif

                extinction = (VL_WaterTransmit + VL_WaterScatter) * sampleDensity;

                sampleTransmittance = exp(-stepDist * extinction);

                vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
                sampleColor *= exp(-waterDepth * extinction);
                sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

                inScattering = VL_WaterScatter * sampleLit * sampleDensity;
            }

            scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;

            sampleLocalPosLast = sampleLocalPos;
        }
    }

    #ifdef SKY_CLOUDS_ENABLED
        if (depth == 1.0 && ap.camera.fluid == 0) {
            float endWorldY = sampleLocalPosLast.y + ap.camera.pos.y;

            if (endWorldY <= cloudHeight && cloudDensity > 0.0)
                vl_renderClouds(transmittance, scattering, miePhase_sun, miePhase_moon, cloud_localPos, cloudDensity, cloud_shadowSun, cloud_shadowMoon);
        }
    #endif

    outScatter = scattering * BufferLumScaleInv;
    outTransmit = transmittance;
}
