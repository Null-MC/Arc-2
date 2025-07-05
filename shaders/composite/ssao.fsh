#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out float out_AO;

uniform sampler2D solidDepthTex;
//uniform usampler2D texDeferredOpaque_Data;
uniform sampler2D texDeferredOpaque_TexNormal;
uniform sampler2D texBlueNoise;

in vec2 uv;

#include "/lib/common.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/blue.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/sampling/depth.glsl"

#include "/lib/utility/matrix.glsl"
#include "/lib/utility/tbn.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif

#define EFFECT_SSAO_RT
#define SSAO_TRACE_ENABLED
const int SSAO_TRACE_SAMPLES = 3;


void main() {
//    ivec2 iuv = ivec2(fma(uv, screenSize, vec2(0.5)));
    ivec2 iuv = ivec2(uv * ap.game.screenSize);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    // vec2 uv_j = uv;
    // #ifdef EFFECT_TAA_ENABLED
    //     vec2 jitterOffset = getJitterOffset(ap.time.frames);
    //     uv_j -= jitterOffset;
    // #endif

    float occlusion = 0.0;

    if (depth < 1.0) {
        #if defined(EFFECT_TAA_ENABLED) || defined(ACCUM_ENABLED)
            float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
            //vec2 dither = sample_blueNoise(gl_FragCoord.xy * 2.0).xy;
        #else
           vec2 dither = vec2(InterleavedGradientNoise(ivec2(gl_FragCoord.xy)));
        #endif

        vec2 pixelSize = 1.0 / ap.game.screenSize;

        vec3 clipPos = vec3(uv, depth);
        vec3 ndcPos = clipPos * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            //unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        float viewDist = length(viewPos);

        #ifdef EFFECT_SSAO_RT
//            float viewDist = length(viewPos);
            float viewDistF = saturate(viewDist / 200.0);
            float max_radius = mix(0.8, 16.0, viewDistF);
        #else
            float distF = min(viewDist * 0.002, 1.0);
            float max_radius = mix(0.8, 8.0, distF);

            float rotatePhase = dither.x * TAU;
            float rStep = 1.0 / EFFECT_SSAO_SAMPLES;
            float radius = rStep;// * dither.y;
        #endif

//         uint data_r = texelFetch(texDeferredOpaque_Data, iuv, 0).r;
//         vec3 normalData = unpackUnorm4x8(data_r).xyz;
        vec3 normalData = texture(texDeferredOpaque_TexNormal, uv).xyz;
        vec3 localNormal = normalize(fma(normalData, vec3(2.0), vec3(-1.0)));

        vec3 viewNormal = normalize(mat3(ap.camera.view) * localNormal);

        #ifdef EFFECT_SSAO_RT
            vec3 viewUp = abs(viewNormal.y) > 0.999 ? ap.camera.viewInv[2].xyz : ap.camera.viewInv[1].xyz;
            vec3 viewTangent = normalize(cross(viewNormal, viewUp));
            const float tangentW = 1.0;

            //float rot_seed = InterleavedGradientNoiseTime(gl_FragCoord.xy);
            mat3 rot = GetTBN(viewNormal, viewTangent, tangentW);// * rotateZ(dither * TAU);
        #endif

        //viewPos += localNormal * 0.06;

        float maxWeight = EPSILON;

        for (int i = 0; i < EFFECT_SSAO_SAMPLES; i++) {
            #ifdef EFFECT_SSAO_RT
//                #ifdef EFFECT_TAA_ENABLED
//                    vec3 offset = hash33(vec3(gl_FragCoord.xy, ap.time.frames + i)) - 0.5;
//                #else
//                    vec3 offset = hash33(vec3(gl_FragCoord.xy, i)) - 0.5;
//                #endif
//
//                offset = normalize(offset) * max_radius * dither;
//                offset *= sign(dot(offset, viewNormal));

                vec2 randomVec = hash33(vec3(gl_FragCoord.xy, ap.time.frames + i)).xy;
                randomVec = randomVec * 2.0 - 1.0;
                //randomVec = _pow2(randomVec) * sign(randomVec);

//                vec2 randomVec = sample_blueNoise(gl_FragCoord.xy + i*vec2(27.0, 13.0)).xz;
//                randomVec = randomVec * 2.0 - 1.0;

                vec3 offset;
                offset.xy = randomVec;
                offset.z = sqrt(1.0 - saturate(dot(offset.xy, offset.xy)));
                offset = normalize(rot * offset) * max_radius;

                offset.z += viewDistF;
                //offset += 0.1 * viewDistF * viewNormal;
            #else
                vec3 offset = radius * max_radius *
                    vec3(sin(rotatePhase), cos(rotatePhase), 0.0);

                radius += rStep;
                rotatePhase += GoldenAngle;
            #endif

            vec3 sampleViewPos = viewPos + offset;
            vec3 sampleClipPos = unproject(ap.camera.projection, sampleViewPos) * 0.5 + 0.5;

            bool skip = false;
            if (saturate(sampleClipPos.xy) != sampleClipPos.xy) skip = true;
            //if (all(lessThan(abs(sampleClipPos.xy - uv), pixelSize))) skip = true;

            float sampleClipDepth = textureLod(solidDepthTex, sampleClipPos.xy, 0.0).r;
            if (sampleClipDepth >= 1.0) skip = true;

            if (!skip) {
                //sampleClipPos.z = sampleClipDepth;
//                vec3 sampleNdcPos = sampleClipPos * 2.0 - 1.0;
                //sampleViewPos = unproject(ap.camera.projectionInv, sampleNdcPos);

//                vec3 diff = sampleViewPos - viewPos;
//                float sampleDist = length(diff);
//                vec3 sampleNormal = diff / sampleDist;

                //float sampleNoLm = max(dot(viewNormal, sampleNormal), 0.0);

                float weight = 1.0;// - saturate(sampleDist / max_radius);

                #ifdef SSAO_TRACE_ENABLED
                    float sampleNoLm = 0.0;

                    const float traceStepSize = 1.0/SSAO_TRACE_SAMPLES;
                    vec3 traceStep = (sampleClipPos - clipPos) * traceStepSize;
                    vec3 traceClipPos = clipPos + dither*traceStep;

                    for (int i = 0; i < SSAO_TRACE_SAMPLES; i++) {
                        float sampleDepth = textureLod(solidDepthTex, traceClipPos.xy, 0).r;
                        float sampleDepthL = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);
                        float traceDepthL = linearizeDepth(traceClipPos.z, ap.camera.near, ap.camera.far);

                        float thickness = 1.0 + 0.2*viewDist;

                        if (traceDepthL > sampleDepthL + EPSILON
                            && traceDepthL < sampleDepthL + thickness) sampleNoLm = 1.0;

                        traceClipPos += traceStep;
                    }

                    // TODO: decrease occlusion based on sample distance to avoid shadowing distant objects
                #else
                    float sampleNoLm = step(sampleClipDepth, sampleClipPos.z);
                #endif

                occlusion += sampleNoLm * weight;
                maxWeight += weight;
            }
        }

        //occlusion = occlusion / max(maxWeight, 1.0);
        occlusion /= maxWeight;
    }

    //occlusion *= 2.0;

    float ao = saturate(occlusion * _pow2(Effect_SSAO_Strength));
    //ao = ao*ao;

    //ao = 1.0 - ao / (ao + 0.5);
    ao = smoothstep(1.0, 0.0, ao);
    //ao = saturate(1.0 - ao);

    out_AO = ao;
}
