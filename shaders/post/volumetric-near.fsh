#version 430 core

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D texSkyTransmit;
uniform sampler2D mainDepthTex;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray solidShadowMap;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/ign.glsl"
#include "/lib/hg.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
#endif

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"

#include "/lib/volumetric.glsl"

const int VL_MaxSamples = 32;


void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    float depth = textureLod(mainDepthTex, uv, 0).r;

    #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif

    vec3 localSunDir = normalize(mat3(playerModelViewInverse) * sunPosition);
    vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);
    float lightStrength = localSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;
    
    float phase_g;
    vec3 scatterF, transmitF;
    vec3 sampleAmbient = vec3(0.0);

    if (isEyeInWater == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase_g = VL_WaterPhase;

        sampleAmbient = VL_WaterAmbient;
    }
    else {
        scatterF = vec3(mix(VL_Scatter, VL_RainScatter, rainStrength));
        transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, rainStrength));
        phase_g = mix(VL_Phase, VL_RainPhase, rainStrength);

        sampleAmbient = vec3(VL_AmbientF);
    }

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    float len = length(localPos);
    float far = farPlane * 0.25;

    if (len > far)
        localPos = localPos / len * far;

    vec3 stepLocal = localPos / (1 + VL_MaxSamples);
    float stepDist = length(stepLocal);

    vec3 localViewDir = normalize(localPos);
    float VoL = dot(localViewDir, localLightDir);
    float phase = HG(VoL, phase_g);

    vec3 shadowViewStart = mul3(shadowModelView, vec3(0.0));
    vec3 shadowViewEnd = mul3(shadowModelView, localPos);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        float shadowSample = 1.0;
        #ifdef SHADOWS_ENABLED
            vec3 shadowViewPos = shadowViewStep*(i+dither) + shadowViewStart;

            vec3 shadowPos;
            int shadowCascade;
            GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
            shadowPos = shadowPos * 0.5 + 0.5;

            if (clamp(shadowPos, 0.0, 1.0) == shadowPos) {
                vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
                float shadowDepth = textureLod(solidShadowMap, shadowCoord, 0).r;
                shadowSample = step(shadowPos.z - 0.000006, shadowDepth);
            }
        #endif

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 skyPos = getSkyPosition(sampleLocalPos);
        vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, localLightDir);
        vec3 sampleColor = lightStrength * skyLighting * shadowSample;

        float sampleDensity = stepDist;
        if (isEyeInWater == 0) {
            sampleDensity = stepDist * GetSkyDensity(sampleLocalPos);

            float worldY = sampleLocalPos.y + cameraPos.y;
            float lightAtmosDist = max(SEA_LEVEL + 200.0 - worldY, 0.0) / localLightDir.y;
            sampleColor *= exp2(-lightAtmosDist * transmitF);
        }

        vec3 sampleLit = phase * sampleColor + phaseIso * sampleAmbient;
        vec3 sampleTransmit = exp(-sampleDensity * transmitF);

        transmittance *= sampleTransmit;
        scattering += scatterF * transmittance * sampleLit * sampleDensity;
    }

    outScatter = scattering;
    outTransmit = transmittance;
}
