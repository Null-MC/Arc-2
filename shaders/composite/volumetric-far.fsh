#version 430 core

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyTransmit;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray solidShadowMap;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/ign.glsl"
#include "/lib/hg.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
#endif

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"

#include "/lib/volumetric.glsl"

const int VL_MaxSamples = 16;


void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    ivec2 iuv = ivec2(uv * screenSize);

    uint data_g = texelFetch(texDeferredTrans_Data, iuv, 0).g;
    float depthOpaque = textureLod(solidDepthTex, uv, 0).r;
    float depthTrans = textureLod(mainDepthTex, uv, 0).r;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    if (depthTrans < depthOpaque) {
        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
        
        float lightStrength = Scene_LocalSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;

        bool isWater = unpackUnorm4x8(data_g).z > 0.5
            && isEyeInWater != 1;

        float phase_g;
        vec3 scatterF, transmitF;
        vec3 sampleAmbient = vec3(0.0);

        if (isWater) {
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

        sampleAmbient *= Scene_SkyIrradianceUp * saturate(eyeBrightness.y);

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
        float stepDist = length(stepLocal);

        vec3 shadowViewStart = mul3(shadowModelView, localPosTrans);
        vec3 shadowViewEnd = mul3(shadowModelView, localPosOpaque);
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

        vec3 localViewDir = normalize(localPosOpaque);
        float VoL = dot(localViewDir, Scene_LocalLightDir);
        float phase = HG(VoL, phase_g);

        // int material = int(unpackUnorm4x8(data_r).w * 255.0 + 0.5);
        // bool isWater = bitfieldExtract(material, 6, 1) != 0
        //     && isEyeInWater != 1;

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

            vec3 sampleLocalPos = (i+dither) * stepLocal + localPosTrans;

            vec3 skyPos = getSkyPosition(sampleLocalPos);
            vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalLightDir);
            vec3 sampleColor = lightStrength * skyLighting * shadowSample;

            float sampleDensity = stepDist;
            if (!isWater) {
                sampleDensity = stepDist * GetSkyDensity(sampleLocalPos);

                float worldY = sampleLocalPos.y + cameraPos.y;
                float lightAtmosDist = max(SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
                sampleColor *= exp2(-0.16 * lightAtmosDist * transmitF);
            }

            vec3 sampleLit = phase * sampleColor + phaseIso * sampleAmbient;
            vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            scattering += scatterF * transmittance * sampleLit * sampleDensity;
            transmittance *= sampleTransmit;
        }
    }

    outScatter = scattering;
    outTransmit = transmittance;
}
