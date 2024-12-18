#version 430 core

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


const int VL_MaxSamples = 64;


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
        phase_gB = -0.08;
        phase_gM = 0.68;

        sampleAmbient = vec3(VL_AmbientF);
    }

    sampleAmbient *= Scene_SkyIrradianceUp * Scene_SkyBrightnessSmooth;

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    float len = length(localPos);
    float far = farPlane * 0.25;

    if (len > far)
        localPos = localPos / len * far;

    vec3 stepLocal = localPos / (VL_MaxSamples);
    float stepDist = length(stepLocal);

    vec3 localViewDir = normalize(localPos);
    float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
    float phase_sun = DHG(VoL_sun, phase_gB, phase_gF, phase_gM);
    float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
    float phase_moon = DHG(VoL_moon, phase_gB, phase_gF, phase_gM);

    vec3 shadowViewStart = mul3(shadowModelView, vec3(0.0));
    vec3 shadowViewEnd = mul3(shadowModelView, localPos);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    float shadowF = min(Scene_LocalLightDir.y * 10.0, 1.0);

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

            float heightLast = sampleLocalPos.y - stepLocal.y;
            if (sampleLocalPos.y+cameraPos.y > cloudHeight && heightLast+cameraPos.y <= cloudHeight) {
                vec3 hit = sampleLocalPos - stepLocal;
                hit += (cloudHeight-cameraPos.y - heightLast) / stepLocal.y * stepLocal;
                hit += cameraPos;

                float detailLow  = textureLod(texFogNoise, vec3(hit.xz * 0.0008, 0.5).xzy, 0).r;
                float detailHigh = textureLod(texFogNoise, vec3(hit.xz * 0.0064, 0.3).xzy, 0).r;
                float cloud_sample = detailLow * ((1.0 - detailHigh)*0.4 + 0.8);

                float cloud_density = mix(200.0, 1200.0, rainStrength);
                float cloud_threshold = mix(0.20, 0.05, rainStrength);
                sampleDensity = cloud_density * smoothstep(cloud_threshold, 1.0, cloud_sample);

                // shadowSample = vec3(1.0);
            }

            // vec3 local_skyPos = sampleLocalPos + cameraPos;
            // local_skyPos.y -= SEA_LEVEL;
            // local_skyPos /= 200.0;//(ATMOSPHERE_MAX - SEA_LEVEL);
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

    outScatter = scattering;
    outTransmit = transmittance;
}
