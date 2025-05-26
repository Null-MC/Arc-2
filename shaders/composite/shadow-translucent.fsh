#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outShadowSSS;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;
uniform sampler2DArray shadowMap;
uniform sampler2DArray solidShadowMap;
uniform sampler2DArray texShadowColor;
uniform usampler2D texDeferredTrans_Data;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/sampling/depth.glsl"

#include "/lib/shadow/csm.glsl"
#include "/lib/shadow/sample.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    //float depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
    float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;

    vec3 shadowFinal = vec3(1.0);
    float sssFinal = 0.0;

//    if (depthTrans < depthOpaque) {
    if (depthTrans < 1.0) {
        uvec2 data = texelFetch(texDeferredTrans_Data, iuv, 0).rg;

        vec3 clipPos = vec3(uv, depthTrans);
        vec3 ndcPos = clipPos * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);

        vec3 data_r = unpackUnorm4x8(data.r).xyz;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        shadowFinal *= step(0.0, dot(localGeoNormal, Scene_LocalLightDir));

        vec3 shadowViewPos = mul3(ap.celestial.view, localPos);

        int shadowCascade;
        vec3 shadowPos = GetShadowSamplePos(shadowViewPos, Shadow_MaxPcfSize, shadowCascade);

        float dither = GetShadowDither();
        
        if (saturate(shadowPos) == shadowPos) {
            shadowFinal *= SampleShadowColor_PCSS(shadowPos, shadowCascade);

            // SSS
            vec4 data_a = unpackUnorm4x8(data.g);
            float sss = data_a.a;

            if (sss > 0.0) {
                float NoLm = max(dot(localGeoNormal, Scene_LocalLightDir), 0.0);

                float sssRadius = sss * MATERIAL_SSS_RADIUS;

                shadowViewPos.z += MATERIAL_SSS_DISTANCE * sss * (dither*dither);
                shadowPos = GetShadowSamplePos(shadowViewPos, sssRadius, shadowCascade);

                vec2 sssRadiusFinal = GetPixelRadius(sssRadius, shadowCascade);
                sssFinal = (1.0 - NoLm) * SampleShadow_PCF(shadowPos, shadowCascade, minOf(sssRadiusFinal));
            }
        }

        #ifdef SHADOWS_SS_FALLBACK
            float viewDist = length(viewPos);
            // vec3 lightViewDir = mat3(gbufferModelView) * localSkyLightDirection;
            vec3 lightViewDir = normalize(ap.celestial.pos);
            vec3 endViewPos = lightViewDir * viewDist * 0.1 + viewPos;

            vec3 clipPosEnd = unproject(ap.camera.projection, endViewPos) * 0.5 + 0.5;

            #ifdef EFFECT_TAA_ENABLED
                clipPosEnd = clipPosEnd * 2.0 - 1.0;
                unjitter(clipPosEnd);
                clipPosEnd = clipPosEnd * 0.5 + 0.5;
            #endif

            vec3 traceScreenDir = normalize(clipPosEnd - clipPos);

            // #ifdef EFFECT_TAA_ENABLED
            //     clipPos.xy += jitterOffset;
            // #endif

            vec2 pixelSize = 1.0 / ap.game.screenSize;

            vec3 traceScreenStep = traceScreenDir * pixelSize.y;
            vec2 traceScreenDirAbs = abs(traceScreenDir.xy);
            // traceScreenStep /= (traceScreenDirAbs.y > 0.5 * aspectRatio ? traceScreenDirAbs.y : traceScreenDirAbs.x);
            traceScreenStep /= mix(traceScreenDirAbs.x, traceScreenDirAbs.y, traceScreenDirAbs.y);

            traceScreenStep *= 2.0;

            vec3 traceScreenPos = traceScreenStep * dither + clipPos;

            int stepCount = 4;
            if (saturate(shadowPos) != shadowPos) {
                stepCount = 16;
                traceScreenStep *= 2.0;
            }

            float traceDist = 0.0;
            float shadowTrace = 1.0;
            for (uint i = 0; i < stepCount; i++) {
                if (shadowTrace < EPSILON) break;
                // if (all(lessThan(shadowTrace * shadowFinal, EPSILON3))) break;

                traceScreenPos += traceScreenStep;

                if (saturate(traceScreenPos) != traceScreenPos) break;

                ivec2 sampleUV = ivec2(traceScreenPos.xy * ap.game.screenSize);
                float sampleDepth = texelFetch(solidDepthTex, sampleUV, 0).r;

                float sampleDepthL = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);

                float traceDepthL = linearizeDepth(traceScreenPos.z, ap.camera.near, ap.camera.far);

                float sampleDiff = traceDepthL - sampleDepthL;
                if (sampleDiff > 0.001 * viewDist) {
                    vec3 traceViewPos = unproject(ap.camera.projectionInv, traceScreenPos * 2.0 - 1.0);

                    traceDist = length(traceViewPos - viewPos);
                    shadowTrace *= step(traceDist, sampleDiff * ShadowScreenSlope);
                }
            }

            shadowFinal *= shadowTrace;

            // #if MATERIAL_SSS != 0
            //     if (traceDist > 0.0) {
            //         //float sss_offset = 0.5 * dither * sss * saturate(1.0 - traceDist / MATERIAL_SSS_MAXDIST);
            //         sssFinal *= 1.0 - saturate(traceDist / MATERIAL_SSS_MAXDIST);
            //     }
            // #endif
        #endif
    }

    outShadowSSS = vec4(shadowFinal, sssFinal);
}
