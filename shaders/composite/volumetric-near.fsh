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

#include "/lib/light/volumetric.glsl"

#ifdef LPV_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
    #include "/lib/lpv/lpv_common.glsl"
    #include "/lib/lpv/lpv_sample.glsl"
#endif


const int VL_MaxSamples = 32;


float SampleCloudDensity(const in vec3 worldPos) {
    float detailLow  = textureLod(texFogNoise, vec3(worldPos.xz * 0.0004, 0.5).xzy, 0).r;
    float detailHigh = textureLod(texFogNoise, vec3(worldPos.xz * 0.0048, 0.3).xzy, 0).r;
    float cloud_sample = detailLow + 0.1*(1.0 - detailHigh);

    float cloud_density = mix(10.0, 40.0, rainStrength);
    float cloud_threshold = mix(0.36, 0.24, rainStrength);
    return cloud_density * smoothstep(cloud_threshold, 0.8, cloud_sample);
}

void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    float depth = textureLod(mainDepthTex, uv, 0).r;

    #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif

    // float lightStrength = Scene_LocalSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;
    
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
        phase_gB = -0.16;
        phase_gM = 0.52;

        sampleAmbient = vec3(VL_AmbientF);
    }

    sampleAmbient *= Scene_SkyIrradianceUp * Scene_SkyBrightnessSmooth;

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
        float cloudLight_sun = 0.0;
        float cloudLight_moon = 0.0;
        if (cameraPos.y < cloudHeight && localPos.y+cameraPos.y > cloudHeight) {
            vec3 cloudPos = (cloudHeight-cameraPos.y) / stepLocal.y * stepLocal;
            cloudPos += cameraPos;

            cloudDensity = SampleCloudDensity(cloudPos);

            float cloudShadowDensity_sun = SampleCloudDensity(cloudPos + 8.0*Scene_LocalSunDir);
            cloudLight_sun = cloudDensity * exp(-0.16*cloudShadowDensity_sun);

            float cloudShadowDensity_moon = SampleCloudDensity(cloudPos - 8.0*Scene_LocalSunDir);
            cloudLight_moon = cloudDensity * exp(-0.16*cloudShadowDensity_moon);

            // shadowSample = vec3(1.0);
        }
    #endif

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        vec3 shadowSample = vec3(shadowF);
        #ifdef SHADOWS_ENABLED
            const float shadowRadius = 2.0*shadowPixelSize;

            vec3 shadowViewPos = shadowViewStep*(i+dither) + shadowViewStart;

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);
            shadowSample *= SampleShadowColor(shadowPos, shadowCascade);
        #endif

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        // vec3 skyPos = getSkyPosition(sampleLocalPos);
        // vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalLightDir);
        vec3 skyPos = getSkyPosition(sampleLocalPos);
        vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
        vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
        vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;
        vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;


        float sampleDensity = stepDist;
        if (isEyeInWater == 0) {
            sampleDensity = stepDist * GetSkyDensity(sampleLocalPos);

            #ifdef CLOUDS_ENABLED
                float heightLast = sampleLocalPos.y - stepLocal.y;
                if (sampleLocalPos.y+cameraPos.y > cloudHeight && heightLast+cameraPos.y <= cloudHeight) {
                    // vec3 hit = sampleLocalPos - stepLocal;
                    // hit += (cloudHeight-cameraPos.y - heightLast) / stepLocal.y * stepLocal;
                    // hit += cameraPos;

                    // sampleDensity = SampleCloudDensity(hit);
                    sampleDensity += cloudDensity;
                    // shadowSample *= cloudShadow;

                    // shadowSample = vec3(1.0);
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
        vec3 sampleLit = sampleColor * shadowSample + phaseIso * sampleAmbient;
        vec3 sampleTransmit = exp(-sampleDensity * transmitF);

        #ifdef CLOUDS_ENABLED
            vec3 sampleLit += sampleColor * (cloudLight_sun + cloudLight_moon);
        #endif

        #ifdef LPV_ENABLED
            vec3 voxelPos = GetVoxelPosition(sampleLocalPos);
            if (IsInVoxelBounds(voxelPos)) {
                vec3 blockLight = sample_lpv_linear(voxelPos, localViewDir);
                sampleLit += 3.0 * phaseIso * blockLight;
            }
        #endif

        transmittance *= sampleTransmit;
        scattering += scatterF * transmittance * sampleLit * sampleDensity;
    }

    #ifdef CLOUDS_ENABLED
        if (traceEnd.y + cameraPos.y < cloudHeight && depth == 1.0) {
            float sampleDensity = cloudDensity;

            vec3 cloud_localPos = (cloudHeight - cameraPos.y) * localViewDir;

            vec3 skyPos = getSkyPosition(cloud_localPos);
            vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
            vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
            vec3 sunSkyLight = SUN_BRIGHTNESS * sunTransmit;
            vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;


            vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = sampleColor * (cloudLight_sun + cloudLight_moon) + phaseIso * sampleAmbient;
            vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            transmittance *= sampleTransmit;
            scattering += scatterF * transmittance * sampleLit * sampleDensity;

            // scattering = vec3(10.0, 0.0, 0.0);
        }
    #endif

    outScatter = scattering;
    outTransmit = transmittance;
}
