#version 430 core

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D texSkyTransmit;
uniform sampler2D mainDepthTex;
uniform sampler2DArray solidShadowMap;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/ign.glsl"
#include "/lib/hg.glsl"
#include "/lib/csm.glsl"
#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/volumetric.glsl"


void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    float depth = textureLod(mainDepthTex, uv, 0).r;
    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);
    vec3 stepLocal = localPos * stepScale;

    vec3 shadowViewStart = mul3(shadowModelView, vec3(0.0));
    vec3 shadowViewEnd = mul3(shadowModelView, localPos);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif
    
    vec3 localSunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);

    vec3 localViewDir = normalize(localPos);
    float VoL = dot(localViewDir, localSunDir);

    float stepDist = length(stepLocal);

    float phase;
    vec3 scatterF, transmitF;
    if (isEyeInWater == 1) {
        scatterF = VL_WaterScatter;
        transmitF = VL_WaterTransmit;
        phase = HG(VoL, 0.36);
    }
    else {
        scatterF = vec3(VL_Scatter);
        transmitF = vec3(VL_Transmit);
        phase = HG(VoL, 0.54);
    }

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    for (int i = 0; i < VL_MaxSamples; i++) {
        vec3 shadowViewPos = shadowViewStep*(i+dither) + shadowViewStart;

        vec3 shadowPos;
        int shadowCascade;
        GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
        shadowPos = shadowPos * 0.5 + 0.5;

        vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
        float shadowDepth = textureLod(solidShadowMap, shadowCoord, 0).r;
        float shadowSample = step(shadowPos.z - 0.000006, shadowDepth);

        if (clamp(shadowPos, 0.0, 1.0) != shadowPos) shadowSample = 1.0;

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 skyPos = getSkyPosition(sampleLocalPos);
        vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, localSunDir);
        vec3 sampleColor = 5.0 * skyLighting * shadowSample;

        float sampleDensity = stepDist;
        if (isEyeInWater == 0) {
            float sampleY = sampleLocalPos.y + cameraPos.y;
            sampleDensity = clamp((sampleY - SEA_LEVEL) / (ATMOSPHERE_MAX - SEA_LEVEL), 0.0, 1.0);
            sampleDensity = stepDist * pow(1.0 - sampleDensity, 8.0);

            sampleDensity *= VL_RainDensity*rainStrength + 1.0;
        }

        vec3 sampleTransmit = exp(-sampleDensity * transmitF);

        transmittance *= sampleTransmit;
        scattering += sampleColor * scatterF * transmittance * (phase * sampleDensity);
    }

    outScatter = scattering;
    outTransmit = transmittance;
}
