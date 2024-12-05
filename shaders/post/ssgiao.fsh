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
const float SSGIAO_RADIUS = 3.0;

const float GOLDEN_ANGLE = 2.39996323;


void main() {
    ivec2 iuv = ivec2(uv * screenSize + 0.5);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 illumination = vec3(0.0);
    float occlusion = 0.0;

    if (depth < 1.0) {
        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
        #else
            float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
        #endif

        const float rStep = SSGIAO_RADIUS / SSGIAO_SAMPLES;

        float rotatePhase = dither * TAU;
        float radius = rStep;

        vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;
        vec3 viewPos = unproject(playerProjectionInverse, clipPos);

        vec2 pixelSize = 1.0 / screenSize;

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
            sampleViewPos = unproject(playerProjectionInverse, sampleClipPos * 2.0 - 1.0);

            vec3 diff = sampleViewPos - viewPos;
            float sampleDist = length(diff);
            vec3 sampleNormal = diff / sampleDist;

            // float sampleNoLm = max(dot(viewNormal, sampleNormal) - SSAO_bias, 0.0) / (1.0 - SSAO_bias);
            float sampleNoLm = max(dot(viewNormal, sampleNormal), 0.0);

            float sampleWeight = saturate(sampleDist / SSGIAO_RADIUS);

            // sampleWeight = pow(sampleWeight, 4.0);
            sampleWeight = 1.0 - sampleWeight;

            illumination += sampleColor * sampleNoLm * sampleWeight;//(sampleWeight*sampleWeight);
            occlusion += sampleNoLm * sampleWeight;
            maxWeight += sampleWeight;
        }

        // ao = ao / max(maxWeight, 1.0) * EFFECT_SSAO_STRENGTH;
        // ao = ao / (ao + rcp(EFFECT_SSAO_STRENGTH));

        // illumination = illumination / max(maxWeight, 1.0);
        occlusion = occlusion / max(maxWeight, 1.0);
    }

    // illumination *= 3.0;
    occlusion *= 2.0;

    vec3 gi = illumination;
    float ao = 1.0 - min(occlusion, 1.0);

    out_GI_AO = vec4(gi, ao);
}
