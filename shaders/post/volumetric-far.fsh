#version 430 core

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyTransmit;
uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;
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

    ivec2 iuv = ivec2(uv * screenSize);

    uint data_g = texelFetch(texDeferredTrans_Data, iuv, 0).g;
    float depthOpaque = textureLod(solidDepthTex, uv, 0).r;
    float depthTrans = textureLod(mainDepthTex, uv, 0).r;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    if (depthTrans < depthOpaque) {
        vec3 ndcPos = vec3(uv, depthOpaque) * 2.0 - 1.0;
        vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPosOpaque = mul3(playerModelViewInverse, viewPos);
        
        float len = length(localPosOpaque);
        float far = farPlane * 0.25;
        
        if (len > far)
            localPosOpaque = localPosOpaque / len * far;

        ndcPos = vec3(uv, depthTrans) * 2.0 - 1.0;
        viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPosTrans = mul3(playerModelViewInverse, viewPos);

        vec3 localRay = localPosOpaque - localPosTrans;
        vec3 stepLocal = localRay * stepScale;

        vec3 shadowViewStart = mul3(shadowModelView, localPosTrans);
        vec3 shadowViewEnd = mul3(shadowModelView, localPosOpaque);
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
        
        vec3 localSunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);

        vec3 localViewDir = normalize(localPosOpaque);
        float VoL = dot(localViewDir, localSunDir);

        float stepDist = length(stepLocal);

        // int material = int(unpackUnorm4x8(data_r).w * 255.0 + 0.5);
        // bool isWater = bitfieldExtract(material, 6, 1) != 0
        //     && isEyeInWater != 1;

        bool isWater = unpackUnorm4x8(data_g).z > 0.5
            && isEyeInWater != 1;

        float phase;
        vec3 scatterF, transmitF;
        if (isWater) {
            scatterF = VL_WaterScatter;
            transmitF = VL_WaterTransmit;
            phase = HG(VoL, VL_WaterPhase);
        }
        else {
            scatterF = vec3(mix(VL_Scatter, VL_RainScatter, rainStrength));
            transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, rainStrength));
            phase = HG(VoL, mix(VL_Phase, VL_RainPhase, rainStrength));
        }

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

            vec3 sampleLocalPos = (i+dither) * stepLocal + localPosTrans;

            vec3 skyPos = getSkyPosition(sampleLocalPos);
            vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, localSunDir);
            vec3 sampleColor = 5.0 * skyLighting * shadowSample;

            float sampleDensity = stepDist;
            if (!isWater) {
                sampleDensity = stepDist * GetSkyDensity(sampleLocalPos);
            }

            vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            scattering += sampleColor * scatterF * transmittance * (phase * sampleDensity);
            transmittance *= sampleTransmit;
        }
    }

    outScatter = scattering;
    outTransmit = transmittance;
}
