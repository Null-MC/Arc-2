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
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
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

#include "/lib/voxel/voxel-common.glsl"

#ifdef SHADOWS_ENABLED
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


void main() {
    const float stepScale = 1.0 / VL_maxSamples_near;

    float depth = textureLod(mainDepthTex, uv, 0).r;

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

    vec3 waterAmbientBase = VL_WaterAmbient * Scene_SkyIrradianceUp;

//    if (Scene_SkyFogDensityF < EPSILON) {
//        outScatter = vec3(0.0);
//        outTransmit = vec3(1.0);
//        return;
//    }

    float far = 128.0;//ap.camera.far * 0.25;

    vec3 traceEnd = localPos;
    if (len > far)
        traceEnd = traceEnd * (far / len);

    //vec3 stepLocal = traceEnd / (VL_maxSamples_near);
    //float stepDist = length(stepLocal);

    vec3 localViewDir = normalize(localPos);
    float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
    float phase_sun = DHG(VoL_sun, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);
    float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
    float phase_moon = DHG(VoL_moon, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);

    vec3 shadowViewStart = mul3(ap.celestial.view, vec3(0.0));
    vec3 shadowViewEnd = mul3(ap.celestial.view, traceEnd);
    //vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    float miePhase_sun = getMiePhase(VoL_sun, 0.2);
    float miePhase_moon = getMiePhase(VoL_moon, 0.2);

    #ifdef SKY_CLOUDS_ENABLED
        float cloudDist = 0.0;
        //float cloudDist2 = 0.0;

        float cloudDensity = 0.0;
        //float cloudDensity2 = 0.0;

        float cloud_shadowSun = 1.0;
        float cloud_shadowMoon = 1.0;

        float cloudShadowF = smoothstep(0.1, 0.2, Scene_LocalLightDir.y);

        vec3 cloud_localPos;
        vec3 cloud_skyPos;

        if (abs(localViewDir.y) > 0.0) {
            if (sign(cloudHeight-ap.camera.pos.y) == sign(localViewDir.y)) {
                cloudDist = abs(cloudHeight-ap.camera.pos.y) / localViewDir.y;

                cloud_localPos = cloudDist * localViewDir;

                vec3 cloudWorldPos = cloud_localPos + ap.camera.pos;

                if (cloudDist < 5000.0) {
                    cloudDensity = SampleCloudDensity(cloudWorldPos);

                    cloud_skyPos = getSkyPosition(cloud_localPos);

                    float shadowStepLen = 2.0;
                    float density_sun = 0.0;
                    float density_moon = 0.0;

                    for (int i = 1; i <= 8; i++) {
                        vec3 step = (i+dither)*shadowStepLen*Scene_LocalSunDir;

                        density_sun  += SampleCloudDensity(cloudWorldPos + step) * shadowStepLen;
                        density_moon += SampleCloudDensity(cloudWorldPos - step) * shadowStepLen;

                        shadowStepLen *= 1.5;
                    }

                    cloudDensity *= 1.0 - smoothstep(2000.0, 5000.0, cloudDist);

                    float extinction = mieScatteringF + mieAbsorptionF;

                    cloud_shadowSun  = 4.0 * exp(-extinction * density_sun);
                    cloud_shadowMoon = 4.0 * exp(-extinction * density_moon);
                }
            }
        }

//        cloudDensity2 = 0.0;
    #endif

    const float renderDistSq = _pow2(ap.camera.renderDistance);

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    const vec3 localPosStart = vec3(0.0);
    vec3 sampleLocalPosLast = vec3(0.0);

    for (int i = 0; i < VL_maxSamples_near; i++) {
        float iF = min(i + dither, VL_maxSamples_near-1);
        float stepF = saturate(iF / (VL_maxSamples_near-1));

        #if VL_STEP_POW != 100
            const float VL_StepPower = VL_STEP_POW * 0.01;
            stepF = pow(stepF, VL_StepPower);
        #endif

        //vec3 sampleLocalPos = iF * stepLocal;
        vec3 sampleLocalPos = mix(localPosStart, traceEnd, stepF);

        float stepDist = length(sampleLocalPos - sampleLocalPosLast);

        vec2 sample_lmcoord = vec2(0.0, 1.0);
        #ifdef VOXEL_PROVIDED
            ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));

            bool isFluid = false;
            uvec2 blockData;
            if (blockWorldPos.y > -64 && blockWorldPos.y < 320 && lengthSq(sampleLocalPos) < renderDistSq) {
                blockData = iris_getBlockAtPos(blockWorldPos).xy;

                uint blockId = blockData.x;
                isFluid = iris_hasFluid(blockId) && iris_getEmission(blockId) == 0;
            }

            if (isFluid) {
                uint blockLightData = blockData.y;

                uvec2 blockLightInt = uvec2(
                    bitfieldExtract(blockLightData,  0, 16),
                    bitfieldExtract(blockLightData, 16, 16));

                sample_lmcoord = saturate(blockLightInt / 240.0);
            }
        #else
            bool isFluid = ap.camera.fluid == 1;
        #endif

        float waterDepth = EPSILON;
        vec3 shadowSample = vec3(1.0);//vec3(smoothstep(0.0, 0.6, Scene_SkyBrightnessSmooth));
        #ifdef SHADOWS_ENABLED
            const float shadowRadius = 2.0*shadowPixelSize;

            //vec3 shadowViewPos = fma(shadowViewStep, vec3(iF), shadowViewStart);
            vec3 shadowViewPos = mix(shadowViewStart, shadowViewEnd, stepF);

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

            float avg_depth = textureLod(texShadowBlocker, vec3(shadowPos.xy, shadowCascade), 0).r;
            float blockerDistance = max(shadowPos.z - avg_depth, 0.0) * GetShadowRange(shadowCascade);
            vec2 pixelRadius = GetPixelRadius(blockerDistance / SHADOW_PENUMBRA_SCALE, shadowCascade);
            //pixelRadius = clamp(pixelRadius, vec2(minShadowPixelRadius), maxPixelRadius);
            shadowPos.xy += (hash23(vec3(gl_FragCoord.xy, i + ap.time.frames)) - 0.5) * pixelRadius;

            shadowSample *= SampleShadowColor(shadowPos, shadowCascade, waterDepth);
            waterDepth = max(waterDepth, EPSILON);
        #endif

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
        float skyLightF = 1.0;//smoothstep(0.0, 0.2, Scene_LocalLightDir.y);
        vec3 sunSkyLight = skyLightF * SUN_LUX * sunTransmit * Scene_SunColor;
        vec3 moonSkyLight = skyLightF * MOON_LUX * moonTransmit;

        float cloudShadow = 1.0;
        #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
            // Cloud Shadows
            if (sampleLocalPos.y+ap.camera.pos.y < cloudHeight) {
                cloudShadow = SampleCloudShadows(sampleLocalPos);
                shadowSample *= cloudShadow;
            }
        #endif

        float vs_shadowF = 1.0;
        float sampleDensity = VL_WaterDensity;
        if (!isFluid) {
            sampleDensity = GetSkyDensity(sampleLocalPos);

            #ifdef SKY_CLOUDS_ENABLED
                //float last_iF = max(iF - 1.0, 0.0);
                //float stepLastF = pow(last_iF / VL_maxSamples_near-1, 1.0);

                //float sampleLocalPosLastY = mix(localPosStart.y, traceEnd.y, stepLastF);
                float sampleHeightLast = sampleLocalPosLast.y+ap.camera.pos.y;

                float sampleHeight = sampleLocalPos.y+ap.camera.pos.y;
                //float heightLast = sampleHeight - stepLocal.y;

                // Clouds
                if (sign(sampleHeight - cloudHeight) != sign(sampleHeightLast - cloudHeight)) {
                    sampleDensity += cloudDensity;

                    sunSkyLight *= cloud_shadowSun;
                    moonSkyLight *= cloud_shadowMoon;

//                    if (cloudDensity > EPSILON)
//                        vs_shadowF *= exp(-cloudDensity);
                }

//                if (sign(sampleHeight - cloudHeight2) != sign(heightLast - cloudHeight2)) {
//                    sampleDensity += cloudDensity2;
//
//                    //sunSkyLight *= cloud_shadowSun;
//                    //moonSkyLight *= cloud_shadowMoon;
//                }
            #endif

            #ifdef SKY_FOG_NOISE
                sampleDensity *= SampleFogNoise(sampleLocalPos);
            #endif

            #ifdef VL_SELF_SHADOW
                float shadow_dither = dither;

                float shadowStepDist = 1.0;
                float shadowDensity = 0.0;
                for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
                    vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + sampleLocalPos;

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
                    vs_shadowF *= exp(-VL_ShadowTransmit * shadowDensity);
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
                vec3 blockLight = sample_AllPointLights_VL(sampleLocalPos, isFluid);
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
                    uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
                    float bright_scale = binLightCount / float(RT_MAX_SAMPLE_COUNT);
                #else
                    uint maxSampleCount = binLightCount;
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
                vec3 blockLight = floodfill_sample(voxelPos);
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

        sampleLit *= 15.0;

        if (!isFluid) {
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

    #ifdef SKY_CLOUDS_ENABLED
        if (depth == 1.0 && ap.camera.fluid == 0) {
            float endWorldY = traceEnd.y + ap.camera.pos.y;
            //endWorldY -= (1.0-dither) * stepLocal.y;

            if (endWorldY < cloudHeight && cloudDensity > 0.0) {
                //vec3 cloud_localPos = cloudDist * localViewDir;

                vec3 sunTransmit, moonTransmit;
                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);

                vec3 sunSkyLight = SUN_LUX * sunTransmit * Scene_SunColor * cloud_shadowSun;
                vec3 moonSkyLight = MOON_LUX * moonTransmit * cloud_shadowMoon;

                vec3 skyPos = getSkyPosition(cloud_localPos);

                float mieScattering = mieScatteringF * cloudDensity;
                float mieAbsorption = mieAbsorptionF * cloudDensity;
                vec3 extinction = vec3(mieScattering + mieAbsorption);

                const float stepDist = 10.0;
                vec3 sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                vec3 ambient = psiMS * Scene_SkyBrightnessSmooth + VL_MinLight;

                vec3 mieInScattering = mieScattering * (miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight + ambient);
                vec3 inScattering = mieInScattering;//rayleighInScattering; // + mieInScattering

                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                scattering += scatteringIntegral * transmittance;
                transmittance *= sampleTransmittance;
            }

//            if (endWorldY < cloudHeight2 && cloudDensity2 > 0.0) {
//                vec3 cloud_localPos = cloudDist2 * localViewDir;
//
//                vec3 sunTransmit, moonTransmit;
//                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);
//
//                vec3 sunSkyLight = SUN_LUX * sunTransmit;
//                vec3 moonSkyLight = MOON_LUX * moonTransmit;
//
//                vec3 skyPos = getSkyPosition(cloud_localPos);
//
//                float mieScattering;
//                vec3 rayleighScattering, extinction;
//                getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);
//
//                vec3 sampleTransmittance = exp(-cloudDensity2 * extinction);
//
//                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
//                psiMS *= Scene_SkyBrightnessSmooth * phaseIso;
//
//                // TODO: add moon
//                vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight + psiMS);
//                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight + psiMS);
//                vec3 inScattering = mieInScattering + rayleighInScattering;
//
//                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;
//
//                scattering += scatteringIntegral*transmittance;
//                transmittance *= sampleTransmittance;
//            }
        }
    #endif

    outScatter = scattering * 0.001;
    outTransmit = transmittance;
}
