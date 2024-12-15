#version 430 core

layout(location = 0) out vec4 outShadow;

in vec2 uv;

uniform sampler2D solidDepthTex;
uniform sampler2DArray solidShadowMap;
uniform usampler2D texDeferredOpaque_Data;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise/ign.glsl"
#include "/lib/depth.glsl"

// #include "/lib/utility/matrix.glsl"

#include "/lib/shadow/csm.glsl"
#include "/lib/shadow/sample.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


const int SHADOW_SCREEN_STEPS = 12;
const float ShadowScreenSlope = 0.85;


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;

    float shadowSample = 1.0;

    if (depthOpaque < 1.0) {
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);

        vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);

        vec3 clipPos = vec3(uv, depthOpaque);
        vec3 ndcPos = clipPos * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPos = mul3(playerModelViewInverse, viewPos);

        vec4 data_r = unpackUnorm4x8(data.r);
        vec3 localNormal = normalize(data_r.xyz * 2.0 - 1.0);
        // int material = int(normalMaterial.w * 255.0 + 0.5);

        vec4 data_a = unpackUnorm4x8(data.a);
        float sss = data_a.a;//bitfieldExtract(material, 2, 1) != 0 ? 1.0 : 0.0;

        // float NoLm = max(dot(localNormal, localLightDir), 0.0);
        // NoLm = mix(NoLm, 1.0, sss);

        shadowSample *= step(0.0, dot(localNormal, localLightDir));

        vec3 shadowViewPos = mul3(shadowModelView, localPos);

        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
        
        shadowViewPos.z += sss * dither;

        int shadowCascade;
        vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowCascade);
        shadowSample *= SampleShadows(shadowPos, shadowCascade);

        #ifdef SHADOW_SCREEN
            float viewDist = length(viewPos);
            // vec3 lightViewDir = mat3(gbufferModelView) * localSkyLightDirection;
            vec3 lightViewDir = normalize(shadowLightPosition);
            vec3 endViewPos = lightViewDir * viewDist * 0.1 + viewPos;

            vec3 clipPosEnd = unproject(playerProjection, endViewPos) * 0.5 + 0.5;

            #ifdef EFFECT_TAA_ENABLED
                clipPosEnd = clipPosEnd * 2.0 - 1.0;
                unjitter(clipPosEnd);
                clipPosEnd = clipPosEnd * 0.5 + 0.5;
            #endif

            vec3 traceScreenDir = normalize(clipPosEnd - clipPos);

            // #ifdef EFFECT_TAA_ENABLED
            //     clipPos.xy += jitterOffset;
            // #endif

            vec2 pixelSize = 1.0 / screenSize;

            vec3 traceScreenStep = traceScreenDir * pixelSize.y;
            vec2 traceScreenDirAbs = abs(traceScreenDir.xy);
            // traceScreenStep /= (traceScreenDirAbs.y > 0.5 * aspectRatio ? traceScreenDirAbs.y : traceScreenDirAbs.x);
            traceScreenStep /= mix(traceScreenDirAbs.x, traceScreenDirAbs.y, traceScreenDirAbs.y);

            traceScreenStep *= 2.0;

            vec3 traceScreenPos = traceScreenStep * dither + clipPos;

            int stepCount = 4;
            if (clamp(shadowPos, 0.0, 1.0) != shadowPos) {
                stepCount = 16;
                traceScreenStep *= 2.0;
            }

            float traceDist = 0.0;
            float shadowTrace = 1.0;
            for (uint i = 0; i < stepCount; i++) {
                if (shadowTrace < EPSILON) break;
                // if (all(lessThan(shadowTrace * shadowFinal, EPSILON3))) break;

                traceScreenPos += traceScreenStep;

                if (clamp(traceScreenPos, 0.0, 1.0) != traceScreenPos) break;

                ivec2 sampleUV = ivec2(traceScreenPos.xy * screenSize);
                float sampleDepth = texelFetch(solidDepthTex, sampleUV, 0).r;

                float sampleDepthL = linearizeDepth(sampleDepth, nearPlane, farPlane);

                float traceDepthL = linearizeDepth(traceScreenPos.z, nearPlane, farPlane);

                float sampleDiff = traceDepthL - sampleDepthL;
                if (sampleDiff > 0.001 * viewDist) {
                    vec3 traceViewPos = unproject(playerProjectionInverse, traceScreenPos * 2.0 - 1.0);

                    traceDist = length(traceViewPos - viewPos);
                    shadowTrace *= step(traceDist, sampleDiff * ShadowScreenSlope);
                }
            }

            shadowSample *= shadowTrace;

            // #if MATERIAL_SSS != 0
            //     if (traceDist > 0.0) {
            //         //float sss_offset = 0.5 * dither * sss * saturate(1.0 - traceDist / MATERIAL_SSS_MAXDIST);
            //         sssFinal *= 1.0 - saturate(traceDist / MATERIAL_SSS_MAXDIST);
            //     }
            // #endif
        #endif
    }

    outShadow = vec4(vec3(shadowSample), 1.0);
}
