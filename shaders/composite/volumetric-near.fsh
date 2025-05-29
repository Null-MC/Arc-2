#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;

uniform sampler3D texFogNoise;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyMultiScatter;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowColor;
#endif

#if LIGHTING_MODE == LIGHT_MODE_LPV
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/hsv.glsl"

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

#if LIGHTING_MODE == LIGHT_MODE_LPV
    #include "/lib/voxel/voxel-common.glsl"
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif


const int VL_MaxSamples = 32;


void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    float depth = textureLod(mainDepthTex, uv, 0).r;

    #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

    float len = length(localPos);

    float phase_gF, phase_gB, phase_gM;
    vec3 scatterF, transmitF;
    vec3 ambientBase = vec3(0.0);

    if (ap.camera.fluid == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase_gF = VL_WaterPhaseF;
        phase_gB = VL_WaterPhaseB;
        phase_gM = VL_WaterPhaseM;

        ambientBase = VL_WaterAmbient * Scene_SkyIrradianceUp;
        //ambientBase *= Scene_SkyBrightnessSmooth;
    }
    else {
        scatterF = vec3(0.0);
        transmitF = vec3(1.0);
        phase_gF = 0.0;
        phase_gB = 0.0;
        phase_gM = 0.0;

        if (Scene_SkyFogDensityF < EPSILON) {
            outScatter = vec3(0.0);
            outTransmit = vec3(1.0);
            return;
        }
    }

    float far = ap.camera.far * 0.5;

    vec3 traceEnd = localPos;
    if (len > far)
        traceEnd = traceEnd / len * far;

    vec3 stepLocal = traceEnd / (VL_MaxSamples);
    float stepDist = length(stepLocal);

    vec3 localViewDir = normalize(localPos);
    float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
    float phase_sun = DHG(VoL_sun, phase_gB, phase_gF, phase_gM);
    float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
    float phase_moon = DHG(VoL_moon, phase_gB, phase_gF, phase_gM);

    vec3 shadowViewStart = mul3(ap.celestial.view, vec3(0.0));
    vec3 shadowViewEnd = mul3(ap.celestial.view, traceEnd);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    float miePhase_sun = 0.0;
    float miePhase_moon = 0.0;

    if (ap.camera.fluid != 1) {
        miePhase_sun = getMiePhase(VoL_sun, 0.2);
        miePhase_moon = getMiePhase(VoL_moon, 0.2);
    }

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

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        float waterDepth = EPSILON;
        vec3 shadowSample = vec3(smoothstep(0.0, 0.6, Scene_SkyBrightnessSmooth));
        #ifdef SHADOWS_ENABLED
            const float shadowRadius = 2.0*shadowPixelSize;

            vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

            shadowSample *= SampleShadowColor(shadowPos, shadowCascade, waterDepth);
            waterDepth = max(waterDepth, EPSILON);
        #endif

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
        float skyLightF = 1.0;//smoothstep(0.0, 0.2, Scene_LocalLightDir.y);
        vec3 sunSkyLight = skyLightF * SUN_LUX * sunTransmit;
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
        if (ap.camera.fluid != 1) {
            sampleDensity = GetSkyDensity(sampleLocalPos);

            #ifdef SKY_CLOUDS_ENABLED
                float sampleHeight = sampleLocalPos.y+ap.camera.pos.y;
                float heightLast = sampleHeight - stepLocal.y;

                // Clouds
                if (sign(sampleHeight - cloudHeight) != sign(heightLast - cloudHeight)) {
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
                sampleDensity += SampleFogNoise(sampleLocalPos);
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

        #if LIGHTING_MODE == LIGHT_MODE_LPV
            vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

            if (floodfill_isInBounds(voxelPos)) {
                vec3 blockLight = floodfill_sample(voxelPos);
                sampleLit += phaseIso * blockLight;
            }
        #endif

//        #ifdef LIGHTING_GI_ENABLED
//            sampleLit += 2000.0;//100000.0 * sample_sh_gi(ivec3(floor(voxelPos)), localViewDir);
//        #endif

        vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;

        bool isFluid;// = ap.camera.fluid == 1;

        ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));
        uint blockId = uint(iris_getBlockAtPos(blockWorldPos).x);
        isFluid = iris_hasFluid(blockId) && iris_getEmission(blockId) == 0;

        if (!isFluid) {
            vec3 skyPos = getSkyPosition(sampleLocalPos);

            float mieDensity = sampleDensity + EPSILON;
            float mieScattering = mieScatteringF * mieDensity;
            float mieAbsorption = mieAbsorptionF * mieDensity;
            extinction = vec3(mieScattering + mieAbsorption);

            sampleTransmittance = exp(-extinction * stepDist);

            vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir) + Sky_MinLight;
            psiMS *= Scene_SkyBrightnessSmooth;

            //vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
            vec3 mieSkyLight = miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight;
            vec3 mieInScattering = mieScattering * (mieSkyLight * shadowSample + psiMS + sampleLit);
            inScattering = mieInScattering;
        }
        else {
            ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));
            uint blockLightData = iris_getBlockAtPos(blockWorldPos).y;
            uint blockSkyLight = bitfieldExtract(blockLightData, 16, 16);
            vec3 sampleAmbient = ambientBase * (blockSkyLight/240.0);

            extinction = transmitF + scatterF;

            shadowSample *= exp(-0.8*waterDepth * sampleDensity * extinction);

            sampleTransmittance = exp(-stepDist * sampleDensity * extinction);

            vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

            inScattering = scatterF * sampleLit * sampleDensity;
        }

        scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;
    }

    #ifdef SKY_CLOUDS_ENABLED
        if (depth == 1.0) {
            float endWorldY = traceEnd.y + ap.camera.pos.y;
            endWorldY -= (1.0-dither) * stepLocal.y;

            if (endWorldY < cloudHeight && cloudDensity > 0.0) {
                //vec3 cloud_localPos = cloudDist * localViewDir;

                vec3 sunTransmit, moonTransmit;
                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);

                vec3 sunSkyLight = SUN_LUX * sunTransmit * cloud_shadowSun;
                vec3 moonSkyLight = MOON_LUX * moonTransmit * cloud_shadowMoon;

                vec3 skyPos = getSkyPosition(cloud_localPos);

                float mieScattering = mieScatteringF * cloudDensity;
                float mieAbsorption = mieAbsorptionF * cloudDensity;
                vec3 extinction = vec3(mieScattering + mieAbsorption);

                vec3 sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir) + Sky_MinLight;
                psiMS *= Scene_SkyBrightnessSmooth;// * phaseIso;

                vec3 mieInScattering = mieScattering * (miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight + psiMS);
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

    outScatter = scattering;
    outTransmit = transmittance;
}
