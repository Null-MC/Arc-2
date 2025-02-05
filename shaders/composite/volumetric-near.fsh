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

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#ifdef LPV_ENABLED
    #include "/lib/buffers/sh-lpv.glsl"
#endif

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
    #include "/lib/lpv/lpv_sample.glsl"
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
    vec3 sampleAmbient = vec3(0.0);

    if (ap.camera.fluid == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase_gF = VL_WaterPhaseF;
        phase_gB = VL_WaterPhaseB;
        phase_gM = VL_WaterPhaseM;

        sampleAmbient = VL_WaterAmbient * Scene_SkyIrradianceUp;
        sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth;
    }
    else {
//        scatterF = vec3(mix(VL_Scatter, VL_RainScatter, ap.world.rainStrength));
//        transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, ap.world.rainStrength));
//        phase_gF = mix(VL_Phase, VL_RainPhase, ap.world.rainStrength);
//        phase_gB = -mix(0.16, 0.28, ap.world.rainStrength);
//        phase_gM =  mix(0.36, 0.24, ap.world.rainStrength);
//
//        sampleAmbient = VL_AmbientF * mix(Scene_SkyIrradianceUp, vec3(0.5*luminance(Scene_SkyIrradianceUp)), ap.world.rainStrength);
    }

//    sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth;
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

    float shadowF = smoothstep(-0.05, 0.05, Scene_LocalLightDir.y);

    float miePhaseValue, rayleighPhaseValue;

    if (ap.camera.fluid != 1) {
        // TODO: add moon
        miePhaseValue = getMiePhase(VoL_sun);
        rayleighPhaseValue = getRayleighPhase(-VoL_sun);
    }

    #ifdef CLOUDS_ENABLED
        float cloudDist = 0.0;
        float cloudDist2 = 0.0;

        float cloudDensity = 0.0;
        float cloudDensity2 = 0.0;

        vec3 cloud_shadowSun = vec3(10.0);// * (1.0 - ap.world.rainStrength);
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

                        float mieScattering;
                        vec3 rayleighScattering, extinction;
                        getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);

                        float sampleDensity = SampleCloudDensity(cloudWorldPos + step);
                        cloud_shadowSun *= exp(-sampleDensity * shadowStepLen * extinction);

                        sampleDensity = SampleCloudDensity(cloudWorldPos - step);
                        cloud_shadowMoon *= exp(-sampleDensity * shadowStepLen * extinction);

                        shadowStepLen *= 1.5;
                    }

                    cloudDensity *= 1.0 - smoothstep(2000.0, 5000.0, cloudDist);
                }
            }

            if (sign(cloudHeight2-ap.camera.pos.y) == sign(localViewDir.y)) {
                cloudDist2 = abs(cloudHeight2-ap.camera.pos.y) / localViewDir.y;
                vec3 cloudPos = cloudDist2 * localViewDir + ap.camera.pos;

                if (cloudDist2 < 8000.0) {
                    cloudDensity2 = SampleCloudDensity2(cloudPos);
                    cloudDensity2 *= 1.0 - smoothstep(5000.0, 8000.0, cloudDist2);
                }
            }
        }

        cloudDensity2 = 0.0;
    #endif

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        vec3 shadowSample = vec3(shadowF);
        #ifdef SHADOWS_ENABLED
            const float shadowRadius = 2.0*shadowPixelSize;

            vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);
            shadowSample *= SampleShadowColor(shadowPos, shadowCascade);
        #endif

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
        vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;
        vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;

        float sampleDensity = 1.0;
        if (ap.camera.fluid != 1) {
            sampleDensity = GetSkyDensity(sampleLocalPos);

            #ifdef CLOUDS_ENABLED
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

//            #define FOG_NOISE
            #ifdef FOG_NOISE
                vec3 local_skyPos = sampleLocalPos + ap.camera.pos;
                local_skyPos.y -= SKY_SEA_LEVEL;
                local_skyPos /= 200.0;//(ATMOSPHERE_MAX - SKY_SEA_LEVEL);
                local_skyPos.xz /= (256.0/32.0);// * 4.0;

                float fogNoise = 0.0;
                fogNoise = textureLod(texFogNoise, local_skyPos, 0).r;
                fogNoise *= 1.0 - textureLod(texFogNoise, local_skyPos * 0.33, 0).r;
                fogNoise = pow(fogNoise, 3);

                fogNoise *= 80.0;

                sampleDensity = sampleDensity * fogNoise + sampleDensity; //pow(fogNoise, 4.0) * 20.0;
            #endif
        }

        vec3 sampleLit = vec3(0.0);

        #ifdef LPV_ENABLED
            vec3 voxelPos = GetVoxelPosition(sampleLocalPos);
            if (IsInVoxelBounds(voxelPos)) {
                vec3 blockLight = sample_lpv_linear(voxelPos, localViewDir);
                sampleLit += blockLight; // * phaseIso
            }
        #endif

        vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;
        if (ap.camera.fluid != 1) {
            vec3 skyPos = getSkyPosition(sampleLocalPos);

            float mieScattering;
            vec3 rayleighScattering;
            getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);

            sampleTransmittance = exp(-sampleDensity * stepDist * extinction);

            vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
            psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth * phaseIso;

            // TODO: add moon
            vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
            vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
            inScattering = (mieInScattering + rayleighInScattering);
        }
        else {
            vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

            extinction = transmitF + scatterF;

            sampleTransmittance = exp(-sampleDensity * stepDist * extinction);

            inScattering = scatterF * sampleLit * sampleDensity;
        }

        scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;
    }

    #ifdef CLOUDS_ENABLED
        if (depth == 1.0) {
            float endWorldY = traceEnd.y + ap.camera.pos.y;
            endWorldY -= (1.0-dither) * stepLocal.y;

            if (endWorldY < cloudHeight && cloudDensity > 0.0) {
                //vec3 cloud_localPos = cloudDist * localViewDir;

                vec3 sunTransmit, moonTransmit;
                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);

                vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit * cloud_shadowSun;
                vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit * cloud_shadowMoon;

                vec3 skyPos = getSkyPosition(cloud_localPos);

                float mieScattering;
                vec3 rayleighScattering, extinction;
                getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);

                vec3 sampleTransmittance = exp(-cloudDensity * stepDist * extinction);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth * phaseIso;

                // TODO: add moon
                vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight + psiMS);
                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight + psiMS);
                vec3 inScattering = mieInScattering + rayleighInScattering;

                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                scattering += scatteringIntegral*transmittance;
                transmittance *= sampleTransmittance;
            }

            if (endWorldY < cloudHeight2 && cloudDensity2 > 0.0) {
                vec3 cloud_localPos = cloudDist2 * localViewDir;

                vec3 sunTransmit, moonTransmit;
                GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);

                vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;
                vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;

                vec3 skyPos = getSkyPosition(cloud_localPos);

                float mieScattering;
                vec3 rayleighScattering, extinction;
                getScatteringValues(skyPos, rayleighScattering, mieScattering, extinction);

                vec3 sampleTransmittance = exp(-cloudDensity2 * extinction);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth * phaseIso;

                // TODO: add moon
                vec3 rayleighInScattering = rayleighScattering * (rayleighPhaseValue * sunSkyLight + psiMS);
                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight + psiMS);
                vec3 inScattering = mieInScattering + rayleighInScattering;

                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                scattering += scatteringIntegral*transmittance;
                transmittance *= sampleTransmittance;
            }
        }
    #endif

    outScatter = scattering;
    outTransmit = transmittance;
}
