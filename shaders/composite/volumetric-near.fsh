#version 430 core

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

#ifdef LPV_ENABLED
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

//#ifdef LPV_ENABLED
//    #include "/lib/buffers/sh-lpv.glsl"
//#endif

#include "/lib/noise/ign.glsl"
#include "/lib/hg.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/clouds.glsl"

#include "/lib/light/volumetric.glsl"

#ifdef LPV_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
    #include "/lib/lpv/lpv_common.glsl"
    //#include "/lib/lpv/lpv_sample.glsl"
    #include "/lib/lpv/floodfill.glsl"
#endif


const int VL_MaxSamples = 32;


#ifdef SKY_FOG_NOISE
    float SampleFogNoise(const in vec3 localPos) {
        vec3 skyPos = localPos + ap.camera.pos;
        skyPos.y -= Scene_SkyFogSeaLevel;

        vec3 samplePos = skyPos;
        samplePos /= 60.0;//(ATMOSPHERE_MAX - SKY_SEA_LEVEL);
        samplePos.xz /= (256.0/32.0);// * 4.0;

        float fogNoise = 0.0;
        fogNoise = textureLod(texFogNoise, samplePos, 0).r;
        fogNoise *= 1.0 - textureLod(texFogNoise, samplePos * 0.33, 0).r;

        //fogNoise = pow(fogNoise, 3.6);
        float threshold_min = mix(0.3, 0.25, ap.world.rainStrength);
        float threshold_max = threshold_min + 0.3;
        fogNoise = smoothstep(threshold_min, 1.0, fogNoise);

        float fogStrength = exp(-0.2 * max(skyPos.y, 0.0));

//        float cloudMin = smoothstep(200.0, 220.0, skyPos.y);
//        float cloudMax = smoothstep(260.0, 240.0, skyPos.y);
//        fogStrength = max(fogStrength, cloudMin * cloudMax);

        fogNoise *= fogStrength;
        fogNoise *= 100.0;

        return fogNoise;
    }
#endif

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
    vec3 sampleAmbient = vec3(0.0);

    if (ap.camera.fluid == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase_gF = VL_WaterPhaseF;
        phase_gB = VL_WaterPhaseB;
        phase_gM = VL_WaterPhaseM;

        sampleAmbient = VL_WaterAmbient * Scene_SkyIrradianceUp;
        sampleAmbient *= Scene_SkyBrightnessSmooth;
    }
    else {
        scatterF = vec3(0.0);
        transmitF = vec3(1.0);
        phase_gF = 0.0;
        phase_gB = 0.0;
        phase_gM = 0.0;
//        scatterF = vec3(mix(VL_Scatter, VL_RainScatter, ap.world.rainStrength));
//        transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, ap.world.rainStrength));
//        phase_gF = mix(VL_Phase, VL_RainPhase, ap.world.rainStrength);
//        phase_gB = -mix(0.16, 0.28, ap.world.rainStrength);
//        phase_gM =  mix(0.36, 0.24, ap.world.rainStrength);
//
//        sampleAmbient = VL_AmbientF * mix(Scene_SkyIrradianceUp, vec3(0.5*luminance(Scene_SkyIrradianceUp)), ap.world.rainStrength);
        if (Scene_SkyFogDensityF < EPSILON) {
            outScatter = vec3(0.0);
            outTransmit = vec3(1.0);
            return;
        }
    }

//    sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth;
    float far = ap.camera.far * 0.25;

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

    float shadowF = smoothstep(-0.05, 0.05, Scene_LocalLightDir.y);

    float miePhase_sun = 0.0;
    float miePhase_moon = 0.0;
    //float rayleighPhaseValue;

    if (ap.camera.fluid != 1) {
        miePhase_sun = getMiePhase(VoL_sun, 0.2);
        miePhase_moon = getMiePhase(VoL_moon, 0.2);
        //rayleighPhaseValue = getRayleighPhase(-VoL_sun);
    }

    #ifdef SKY_CLOUDS_ENABLED
        float cloudDist = 0.0;
        float cloudDist2 = 0.0;

        float cloudDensity = 0.0;
        float cloudDensity2 = 0.0;

        vec3 cloud_shadowSun = vec3(200.0);// * (1.0 - ap.world.rainStrength);
        vec3 cloud_shadowMoon = vec3(1.0);// * (1.0 - ap.world.rainStrength);

        float cloudShadowF = smoothstep(0.1, 0.2, Scene_LocalLightDir.y);

        vec3 cloud_localPos;

//        float cloud_mieScattering;
//        vec3 cloud_rayleighScattering, cloud_extinction;
        vec3 cloud_skyPos;

        if (abs(localViewDir.y) > 0.0) {
            if (sign(cloudHeight-ap.camera.pos.y) == sign(localViewDir.y)) {
                cloudDist = abs(cloudHeight-ap.camera.pos.y) / localViewDir.y;

                cloud_localPos = cloudDist * localViewDir;

                vec3 cloudWorldPos = cloud_localPos + ap.camera.pos;

                if (cloudDist < 5000.0) {
                    cloudDensity = SampleCloudDensity(cloudWorldPos);

                    cloud_skyPos = getSkyPosition(cloud_localPos);

                    //getScatteringValues(cloud_skyPos, cloud_rayleighScattering, cloud_mieScattering, cloud_extinction);

                    //float cloud_transmitF = mix(VL_Transmit, VL_RainTransmit, ap.world.rainStrength);

                    float shadowStepLen = 2.0;

                    for (int i = 1; i <= 8; i++) {
                        vec3 step = (i+dither)*shadowStepLen*Scene_LocalSunDir;

                        vec3 skyPos = getSkyPosition(cloud_localPos + step);
                        float sampleDensity = SampleCloudDensity(cloudWorldPos + step);

                        //float mieScattering;
                        //vec3 rayleighScattering, extinction;
                        //getScatteringValues(skyPos, sampleDensity, rayleighScattering, mieScattering, extinction);
//                        float altitudeKM = (length(skyPos)-groundRadiusMM) * 1000.0;
//                        float rayleighDensity = exp(-altitudeKM/8.0);
//                        vec3 rayleighScattering = rayleighScatteringBase * rayleighDensity;
//                        float rayleighAbsorption = rayleighAbsorptionBase * rayleighDensity;
//                        vec3 extinction = rayleighScattering + rayleighAbsorption;// + mieScattering + mieAbsorption + ozoneAbsorption;
                        float mieDensity = sampleDensity;
                        float mieScattering = 0.0004 * mieDensity;
                        float mieAbsorption = 0.0020 * mieDensity;
                        vec3 extinction = vec3(mieScattering + mieAbsorption);

                        cloud_shadowSun *= exp(-extinction);

                        sampleDensity = SampleCloudDensity(cloudWorldPos - step);
                        cloud_shadowMoon *= exp(-sampleDensity * shadowStepLen * extinction);

                        shadowStepLen *= 1.5;
                    }

                    cloudDensity *= 1.0 - smoothstep(2000.0, 5000.0, cloudDist);
                }
            }

//            if (sign(cloudHeight2-ap.camera.pos.y) == sign(localViewDir.y)) {
//                cloudDist2 = abs(cloudHeight2-ap.camera.pos.y) / localViewDir.y;
//                vec3 cloudPos = cloudDist2 * localViewDir + ap.camera.pos;
//
//                if (cloudDist2 < 8000.0) {
//                    cloudDensity2 = SampleCloudDensity2(cloudPos);
//                    cloudDensity2 *= 1.0 - smoothstep(5000.0, 8000.0, cloudDist2);
//                }
//            }
        }

        cloudDensity2 = 0.0;
    #endif

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        float waterDepth = EPSILON;
        vec3 shadowSample = vec3(shadowF);
        #ifdef SHADOWS_ENABLED
            const float shadowRadius = 2.0*shadowPixelSize;

            vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

            // TODO: get light depth for water absorb
            shadowSample *= SampleShadowColor(shadowPos, shadowCascade, waterDepth);
            waterDepth = max(waterDepth, EPSILON);
        #endif

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
        vec3 sunSkyLight = SUN_LUMINANCE * sunTransmit;
        vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;

        float sampleDensity = 1.0;
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
                }

                if (sign(sampleHeight - cloudHeight2) != sign(heightLast - cloudHeight2)) {
                    sampleDensity += cloudDensity2;

                    //sunSkyLight *= cloud_shadowSun;
                    //moonSkyLight *= cloud_shadowMoon;
                }

                #ifdef SHADOWS_CLOUD_ENABLED
                    // Cloud Shadows
                    if (sampleLocalPos.y+ap.camera.pos.y < cloudHeight) {
                        vec3 worldPos = sampleLocalPos + ap.camera.pos;
                        worldPos += (cloudHeight - worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir;

                        float cloudShadowDensity = SampleCloudDensity(worldPos);
                        shadowSample *= mix(1.0, exp(-0.2*cloudShadowDensity), cloudShadowF);
                    }

                    if (sampleLocalPos.y+ap.camera.pos.y < cloudHeight2) {
                        vec3 worldPos = sampleLocalPos + ap.camera.pos;
                        worldPos += (cloudHeight2 - worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir;

                        float cloudShadowDensity = SampleCloudDensity2(worldPos);
                        shadowSample *= mix(1.0, exp(-0.2*cloudShadowDensity), cloudShadowF);
                    }
                #endif
            #endif

            #ifdef SKY_FOG_NOISE
                float fogNoise = SampleFogNoise(sampleLocalPos);
                sampleDensity += fogNoise;

                float shadow_dither = dither;

                float shadowStepDist = 1.0;
                float shadowDensity = 0.0;
                for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
                    vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + sampleLocalPos;
                    shadowDensity += SampleFogNoise(fogShadow_localPos) * shadowStepDist;// * (1.0 - max(1.0 - ii, 0.0));
                    shadowStepDist *= 2.0;
                }

                if (shadowDensity > 0.0)
                    shadowSample *= exp(-shadowDensity * 0.2);
            #else
                // TODO: TF?
            #endif
        }

        vec3 sampleLit = vec3(0.0);

        #ifdef LPV_ENABLED
            vec3 voxelPos = GetVoxelPosition(sampleLocalPos);
            if (IsInVoxelBounds(voxelPos)) {
                vec3 blockLight = sample_floodfill(voxelPos);
                sampleLit += blockLight * BLOCKLIGHT_LUMINANCE; // * phaseIso;
            }
        #endif

        vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;
        if (ap.camera.fluid != 1) {
            vec3 skyPos = getSkyPosition(sampleLocalPos);

            float mieDensity = sampleDensity + EPSILON;
            float mieScattering = 0.0004 * mieDensity;
            float mieAbsorption = 0.0020 * mieDensity;
            extinction = vec3(mieScattering + mieAbsorption);

            sampleTransmittance = exp(-extinction * stepDist);

            vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
            psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth;

            //vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
            vec3 mieSkyLight = miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight;
            vec3 mieInScattering = mieScattering * (mieSkyLight * shadowSample + psiMS + sampleLit);
            inScattering = mieInScattering;
        }
        else {
            extinction = transmitF + scatterF;

            shadowSample *= exp(-0.2*waterDepth * sampleDensity * extinction);

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

                vec3 sunSkyLight = SUN_LUMINANCE * sunTransmit * cloud_shadowSun;
                vec3 moonSkyLight = MOON_LUMINANCE * moonTransmit * cloud_shadowMoon;

                vec3 skyPos = getSkyPosition(cloud_localPos);

                //float mieScattering;
                //vec3 rayleighScattering, extinction;
                //getScatteringValues(skyPos, 1.0, rayleighScattering, mieScattering, extinction);
                float mieDensity = cloudDensity;
                float mieScattering = 0.0004 * mieDensity;
                float mieAbsorption = 0.0020 * mieDensity;
                vec3 extinction = vec3(mieScattering + mieAbsorption);

                vec3 sampleTransmittance = exp(-extinction * stepDist); //?

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth;// * phaseIso;

                // TODO: add moon
                //vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight + psiMS);
                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight + psiMS);
                vec3 inScattering = mieInScattering;//rayleighInScattering; // + mieInScattering

                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                scattering += scatteringIntegral*transmittance;
                transmittance *= sampleTransmittance;
            }

//            if (endWorldY < cloudHeight2 && cloudDensity2 > 0.0) {
//                vec3 cloud_localPos = cloudDist2 * localViewDir;
//
//                vec3 sunTransmit, moonTransmit;
//                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);
//
//                vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;
//                vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;
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
//                psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth * phaseIso;
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
