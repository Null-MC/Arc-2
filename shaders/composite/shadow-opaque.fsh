#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outShadowSSS;

in vec2 uv;

uniform sampler2D solidDepthTex;
uniform sampler2DArray shadowMap;
uniform sampler2DArray solidShadowMap;
uniform sampler2DArray texShadowColor;
uniform sampler2DArray texShadowBlocker;
uniform usampler2D texDeferredOpaque_Data;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if defined(SHADOW_VOXEL_TEST) && !defined(VOXEL_PROVIDED)
    #include "/lib/buffers/voxel-block.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/sampling/depth.glsl"
#include "/lib/light/volumetric.glsl"

#include "/lib/shadow/csm.glsl"
#include "/lib/shadow/sample.glsl"

#ifdef SHADOW_VOXEL_TEST
    #include "/lib/voxel/voxel-common.glsl"
    #include "/lib/voxel/voxel-sample.glsl"
    #include "/lib/voxel/dda.glsl"
#endif

#ifdef SHADOW_DISTORTION_ENABLED
    #include "/lib/shadow/distorted.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 shadowFinal = vec3(1.0);
    float sssFinal = 0.0;

    if (depthOpaque < 1.0) {
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        uint blockId = data.a;

        vec3 clipPos = vec3(uv, depthOpaque);
        vec3 ndcPos = clipPos * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        if (blockId == BLOCK_HAND) {
            ndcPos.z /= MC_HAND_DEPTH;
        }

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);

        vec3 data_r = unpackUnorm4x8(data.r).xyz;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        shadowFinal *= step(0.0, dot(localGeoNormal, Scene_LocalLightDir));


        bool voxelHit = false;
        #ifdef SHADOW_VOXEL_TEST
            vec3 sampleLocalPos = localPos + 0.08 * localGeoNormal;
            vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

            vec3 stepSizes, nextDist, stepAxis;
            dda_init(stepSizes, nextDist, voxelPos, Scene_LocalLightDir);

            vec3 currPos = voxelPos;
            for (int i = 0; i < 4; i++) {
                vec3 step = dda_step(stepAxis, nextDist, stepSizes, Scene_LocalLightDir);

                ivec3 traceVoxelPos = ivec3(floor(currPos + 0.5*step));
                if (!voxel_isInBounds(traceVoxelPos)) break;

                uint blockId = SampleVoxelBlock(traceVoxelPos);
                if (blockId != -1u) {
                    bool isFullBlock = iris_isFullBlock(blockId);
                    if (isFullBlock) {
                        voxelHit = true;
                        shadowFinal = vec3(0.0);
                        break;
                    }
                }

                currPos += step;
            }
        #endif


        vec3 shadowViewPos = mul3(ap.celestial.view, localPos);

        int shadowCascade;
        vec3 shadowPos = GetShadowSamplePos(shadowViewPos, Shadow_MaxPcfSize, shadowCascade);

        #ifdef SHADOW_DISTORTION_ENABLED
            shadowPos = shadowPos * 2.0 - 1.0;
            shadowPos = shadowDistort(shadowPos);
            shadowPos = shadowPos * 0.5 + 0.5;
        #endif

        float dither = GetShadowDither();
        
        if (saturate(shadowPos) == shadowPos && !voxelHit) {
            if (lengthSq(shadowFinal) > 0.0) {
                #ifdef SHADOW_PCSS_ENABLED
                    shadowFinal *= SampleShadowColor_PCSS(shadowPos, shadowCascade);
                #else
                    float bias = GetShadowBias(shadowCascade);
                    shadowPos.z -= bias;

                    shadowFinal *= SampleShadowColor(shadowPos, shadowCascade);
                #endif

                float shadowRange = GetShadowRange(shadowCascade);
                vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
                float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;
                float depthTrans = textureLod(shadowMap, shadowCoord, 0).r;
                float waterDepth = max(depthOpaque - depthTrans, 0.0) * shadowRange;

                if (waterDepth > 0.0) {
                    // TODO: add a water mask to shadows
                    shadowFinal *= exp(-waterDepth * VL_WaterTransmit * VL_WaterDensity);
                }
            }

            // SSS
            vec4 data_a = unpackUnorm4x8(data.g);
            float sss = data_a.a;

            if (sss > 0.0) {
                //float NoLm = max(dot(localGeoNormal, Scene_LocalLightDir), 0.0);

                //float sss_2 = _pow3(sss);
                float sssRadius = _pow3(sss) * MATERIAL_SSS_RADIUS;
                //float sssDist = sss_2 * MATERIAL_SSS_DISTANCE * pow5(dither);

//                shadowViewPos.z += sssDist;

                shadowPos = GetShadowSamplePos(shadowViewPos, sssRadius, shadowCascade);

                #ifdef SHADOW_DISTORTION_ENABLED
                    shadowPos = shadowPos * 2.0 - 1.0;
                    shadowPos = shadowDistort(shadowPos);
                    shadowPos = shadowPos * 0.5 + 0.5;
                #endif

                vec2 sssRadiusFinal = GetPixelRadius(sssRadius, shadowCascade);
                sssFinal = SampleShadow_PCF(shadowPos, shadowCascade, minOf(sssRadiusFinal), sss);
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
