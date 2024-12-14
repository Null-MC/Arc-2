#version 430 core

layout(location = 0) out vec4 out_GI_AO;

uniform sampler2D solidDepthTex;
uniform sampler2D texFinalPrevious;
uniform usampler2D texDeferredOpaque_Data;

in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/ign.glsl"

const int SSGIAO_SAMPLES = 16;
const float SSGIAO_RADIUS = 4.0;

const bool SSGIAO_TRACE_ENABLED = true;
const int SSGIAO_TRACE_SAMPLES = 3;

const float GOLDEN_ANGLE = 2.39996323;


void main() {
    ivec2 iuv = ivec2(uv * screenSize + 0.5);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 illumination = vec3(0.0);
    float occlusion = 0.0;

    if (depth < 1.0) {
        #if defined EFFECT_TAA_ENABLED || defined ACCUM_ENABLED
            float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
        #else
            float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
        #endif

        const float rStep = SSGIAO_RADIUS / SSGIAO_SAMPLES;

        vec2 pixelSize = 1.0 / screenSize;

        float rotatePhase = dither * TAU;
        float radius = rStep * dither;

        vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;
        vec3 viewPos = unproject(playerProjectionInverse, clipPos);

        uint data_r = texelFetch(texDeferredOpaque_Data, iuv, 0).r;
        vec3 data_normal = unpackUnorm4x8(data_r).xyz;
        vec3 localNormal = normalize(data_normal * 2.0 - 1.0);
        vec3 viewNormal = mat3(playerModelView) * localNormal;

        float maxWeight = 0.0;

        for (int i = 0; i < SSGIAO_SAMPLES; i++) {
            vec2 offset = radius * vec2(
                sin(rotatePhase),
                cos(rotatePhase));

            radius += rStep;
            rotatePhase += GOLDEN_ANGLE;

            vec3 sampleViewPos = viewPos + vec3(offset, 0.0);
            vec3 sampleClipPos = unproject(playerProjection, sampleViewPos) * 0.5 + 0.5;

            if (clamp(sampleClipPos.xy, 0.0, 1.0) != sampleClipPos.xy) continue;
            if (all(lessThan(abs(sampleClipPos.xy - uv), pixelSize))) continue;

            float sampleClipDepth = textureLod(solidDepthTex, sampleClipPos.xy, 0.0).r;

            if (sampleClipDepth >= 1.0) continue;

            vec3 sampleColor = textureLod(texFinalPrevious, sampleClipPos.xy, 0).rgb;

            sampleClipPos.z = sampleClipDepth;
            sampleClipPos = sampleClipPos * 2.0 - 1.0;
            sampleViewPos = unproject(playerProjectionInverse, sampleClipPos);

            float gi_weight = 1.0;
            if (SSGIAO_TRACE_ENABLED) {
                vec3 traceRay = sampleClipPos - clipPos;
                vec3 traceStep = traceRay / (SSGIAO_TRACE_SAMPLES+1);
                vec3 tracePos = clipPos;

                for (int t = 0; t < SSGIAO_TRACE_SAMPLES; t++) {
                    tracePos += traceStep;
                    float traceSampleDepth = textureLod(solidDepthTex, tracePos.xy * 0.5 + 0.5, 0.0).r * 2.0 - 1.0;

                    if (tracePos.z >= traceSampleDepth) {
                        gi_weight = 0.0;
                        break;
                    }
                }
            }

            if (abs(sampleViewPos.z - viewPos.z) > SSGIAO_RADIUS) gi_weight = 0.0;

            vec3 diff = sampleViewPos - viewPos;
            float sampleDist = length(diff);
            vec3 sampleNormal = diff / sampleDist;

            float sampleNoLm = max(dot(viewNormal, sampleNormal), 0.0);

            float sampleWeight = saturate(sampleDist / SSGIAO_RADIUS);

            sampleWeight = 1.0 - sampleWeight;

            // gi_weight *= 1.0 / (1.0 + sampleDist);

            illumination += sampleColor * sampleNoLm * gi_weight;
            occlusion += sampleNoLm * sampleWeight;
            maxWeight += sampleWeight;
        }

        occlusion = occlusion / max(maxWeight, 1.0);
    }

    // occlusion *= 2.0;

    vec3 gi = illumination;
    float ao = 1.0 - min(occlusion, 1.0);

    out_GI_AO = vec4(gi, ao);
}
