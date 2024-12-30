#version 430 core
#extension GL_NV_gpu_shader5: enable

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;

uniform sampler3D texFogNoise;
uniform sampler2D texSkyTransmit;

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
    
    float phase_gF, phase_gB, phase_gM;
    vec3 scatterF, transmitF;
    vec3 sampleAmbient = vec3(0.0);

    if (isEyeInWater == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase_gF = VL_WaterPhase;
        phase_gB = -0.08;
        phase_gM = 0.96;

        sampleAmbient = VL_WaterAmbient;
    }
    else {
        scatterF = vec3(mix(VL_Scatter, VL_RainScatter, rainStrength));
        transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, rainStrength));
        phase_gF = mix(VL_Phase, VL_RainPhase, rainStrength);
        phase_gB = -0.32;
        phase_gM = 0.36;

        sampleAmbient = vec3(VL_AmbientF);
    }

    sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth * Scene_SkyIrradianceUp;

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    float len = length(localPos);
    float far = farPlane * 0.25;

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

    vec3 shadowViewStart = mul3(shadowModelView, vec3(0.0));
    vec3 shadowViewEnd = mul3(shadowModelView, traceEnd);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    float shadowF = min(Scene_LocalLightDir.y * 10.0, 1.0);

    #ifdef CLOUDS_ENABLED
        float cloudDensity = 0.0;
        float cloud_shadowSun = 20.0;
        float cloud_shadowMoon = 10.0;
        if (cameraPos.y < cloudHeight && localViewDir.y > 0.0) {
            vec3 cloudPos = (cloudHeight-cameraPos.y) / stepLocal.y * stepLocal;
            float cloudDist = length(cloudPos);
            cloudPos += cameraPos;

            if (cloudDist < 5000.0) {
                cloudDensity = SampleCloudDensity(cloudPos);

                float cloud_transmitF = mix(VL_Transmit, VL_RainTransmit, rainStrength);

                const float shadowStepLen = 24.0;

                for (int i = 1; i <= 8; i--) {
                    vec3 step = (i+dither)*shadowStepLen*Scene_LocalSunDir;

                    float sampleDensity = SampleCloudDensity(cloudPos + step);
                    cloud_shadowSun *= exp(-2.0*shadowStepLen*sampleDensity * cloud_transmitF);

                    sampleDensity = SampleCloudDensity(cloudPos - step);
                    cloud_shadowMoon *= exp(-2.0*shadowStepLen*sampleDensity * cloud_transmitF);
                }

                cloudDensity *= 1.0 - smoothstep(2000.0, 5000.0, cloudDist);
            }
        }

        float cloudHeight2 = cloudHeight + 120.0;

        float cloudDensity2 = 0.0;
        if (cameraPos.y < cloudHeight2 && localViewDir.y > 0.0) {
            vec3 cloudPos = (cloudHeight2-cameraPos.y) / stepLocal.y * stepLocal;
            float cloudDist = length(cloudPos);
            cloudPos += cameraPos;

            if (cloudDist < 5000.0) {
                cloudDensity2 = SampleCloudDensity2(cloudPos);
                cloudDensity2 *= 1.0 - smoothstep(2000.0, 5000.0, cloudDist);
            }
        }
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

        float sampleDensity = stepDist;
        if (isEyeInWater == 0) {
            sampleDensity = stepDist * GetSkyDensity(sampleLocalPos);

            #ifdef CLOUDS_ENABLED
                float heightLast = sampleLocalPos.y - stepLocal.y;
                if (sampleLocalPos.y+cameraPos.y > cloudHeight && heightLast+cameraPos.y <= cloudHeight) {
                    sampleDensity += cloudDensity;

                    sunSkyLight *= cloud_shadowSun;
                    moonSkyLight *= cloud_shadowMoon;
                }

                if (sampleLocalPos.y+cameraPos.y < cloudHeight) {
                    vec3 worldPos = sampleLocalPos + cameraPos;
                    worldPos += (cloudHeight - worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir;

                    float cloudShadowDensity = SampleCloudDensity(worldPos);
                    shadowSample *= exp(-0.2*cloudShadowDensity);
                }
            #endif

            // vec3 local_skyPos = sampleLocalPos + cameraPos;
            // local_skyPos.y -= SKY_SEA_LEVEL;
            // local_skyPos /= 200.0;//(ATMOSPHERE_MAX - SKY_SEA_LEVEL);
            // local_skyPos.xz /= (256.0/32.0);// * 4.0;

            // float fogNoise = 0.0;
            // fogNoise = textureLod(texFogNoise, local_skyPos, 0).r;
            // fogNoise *= 1.0 - textureLod(texFogNoise, local_skyPos * 0.33, 0).r;
            // fogNoise = pow(fogNoise, 3);

            // fogNoise *= 80.0;

            // sampleDensity = sampleDensity * fogNoise + sampleDensity; //pow(fogNoise, 4.0) * 20.0;
        }

        vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
        vec3 sampleLit = fma(sampleColor, shadowSample, sampleAmbient);
        vec3 sampleTransmit = exp(-sampleDensity * transmitF);

        // #ifdef CLOUDS_ENABLED
        //     sampleLit += sampleColor * (cloudLight_sun + cloudLight_moon);
        // #endif

        #ifdef LPV_ENABLED
            vec3 voxelPos = GetVoxelPosition(sampleLocalPos);
            if (IsInVoxelBounds(voxelPos)) {
                vec3 blockLight = sample_lpv_linear(voxelPos, localViewDir);
                sampleLit += phaseIso * blockLight;
            }
        #endif

        transmittance *= sampleTransmit;
        scattering += scatterF * transmittance * sampleLit * sampleDensity;
    }

    #ifdef CLOUDS_ENABLED
        if (traceEnd.y + cameraPos.y < cloudHeight && depth == 1.0) {
            vec3 cloud_localPos = (cloudHeight - cameraPos.y) / localViewDir.y * localViewDir;

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);
            vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit * cloud_shadowSun;
            vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit * cloud_shadowMoon;

            vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = sampleColor + sampleAmbient;
            vec3 sampleTransmit = exp(-cloudDensity * transmitF);

            transmittance *= sampleTransmit;
            scattering += scatterF * transmittance * sampleLit * cloudDensity;
        }

        if (traceEnd.y + cameraPos.y < cloudHeight2 && depth == 1.0) {
            vec3 cloud_localPos = (cloudHeight2 - cameraPos.y) / localViewDir.y * localViewDir;

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);
            vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;// * cloud_shadowSun;
            vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;// * cloud_shadowMoon;

            vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = sampleColor + sampleAmbient;
            vec3 sampleTransmit = exp(-cloudDensity2 * transmitF);

            transmittance *= sampleTransmit;
            scattering += scatterF * transmittance * sampleLit * cloudDensity2;
        }
    #endif

    outScatter = scattering;
    outTransmit = transmittance;
}
