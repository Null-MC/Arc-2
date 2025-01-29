#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 out_GI_AO;

uniform sampler2D solidDepthTex;
uniform sampler2D texDeferredOpaque_TexNormal;

#ifdef EFFECT_SSGI_ENABLED
    uniform sampler2D texFinalPrevious;
#endif

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/noise/ign.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif

const int SSGIAO_SAMPLES = 8;
// const float SSGIAO_RADIUS = 4.0;

#define SSGIAO_TRACE_ENABLED
const int SSGIAO_TRACE_SAMPLES = 3;


void main() {
//    ivec2 iuv = ivec2(fma(uv, screenSize, vec2(0.5)));
    ivec2 iuv = ivec2(uv * ap.game.screenSize);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    // vec2 uv_j = uv;
    // #ifdef EFFECT_TAA_ENABLED
    //     vec2 jitterOffset = getJitterOffset(ap.frame.counter);
    //     uv_j -= jitterOffset;
    // #endif

    vec3 illumination = vec3(0.0);
    float occlusion = 0.0;

    if (depth < 1.0) {
         #if defined EFFECT_TAA_ENABLED || defined ACCUM_ENABLED
             float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
         #else
            float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
         #endif

        vec2 pixelSize = 1.0 / ap.game.screenSize;

        float rotatePhase = dither * TAU;

        vec3 clipPos = vec3(uv, depth);
        vec3 ndcPos = clipPos * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            //unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);

        float viewDist = length(viewPos);

        float distF = min(viewDist * 0.005, 1.0);
        float max_radius_ao = mix(0.5, 12.0, distF);
        float max_radius_gi = mix(2.0, 16.0, distF);

        float rStep = 1.0 / SSGIAO_SAMPLES;
        float radius = rStep * dither;

        // uint data_r = texelFetch(texDeferredOpaque_Data, iuv, 0).r;
        // vec3 normalData = unpackUnorm4x8(data_r).xyz;
        vec3 normalData = texelFetch(texDeferredOpaque_TexNormal, iuv, 0).xyz;
        vec3 localNormal = normalize(fma(normalData, vec3(2.0), vec3(-1.0)));

        vec3 viewNormal = normalize(mat3(ap.camera.view) * localNormal);

        //viewPos += localNormal * 0.06;

        float maxWeight = EPSILON;

        for (int i = 0; i < SSGIAO_SAMPLES; i++) {
            vec2 offset = radius * vec2(sin(rotatePhase), cos(rotatePhase));
            vec2 offset_ao = offset * max_radius_ao;
            vec2 offset_gi = offset * max_radius_gi;

            radius += rStep;
            rotatePhase += GoldenAngle;

            #ifdef EFFECT_SSAO_ENABLED
                vec3 sampleViewPos_ao = viewPos + vec3(offset_ao, 0.0);
                vec3 sampleClipPos_ao = unproject(ap.camera.projection, sampleViewPos_ao) * 0.5 + 0.5;

                bool skip_ao = false;
                if (clamp(sampleClipPos_ao.xy, 0.0, 1.0) != sampleClipPos_ao.xy) skip_ao = true;
                //if (all(lessThan(abs(sampleClipPos_ao.xy - uv), pixelSize))) skip_ao = true;

                float sampleClipDepth_ao = textureLod(solidDepthTex, sampleClipPos_ao.xy, 0.0).r;
                if (sampleClipDepth_ao >= 1.0) skip_ao = true;

                if (!skip_ao) {
                    sampleClipPos_ao.z = sampleClipDepth_ao;
                    sampleClipPos_ao = sampleClipPos_ao * 2.0 - 1.0;
                    sampleViewPos_ao = unproject(ap.camera.projectionInv, sampleClipPos_ao);

                    vec3 diff = sampleViewPos_ao - viewPos;
                    float sampleDist = length(diff);
                    vec3 sampleNormal = diff / sampleDist;

                    float sampleNoLm = max(dot(viewNormal, sampleNormal), 0.0);

                    float ao_weight = 1.0 - saturate(sampleDist / max_radius_ao);

                    occlusion += sampleNoLm * ao_weight;

                    maxWeight += ao_weight;
                }
            #endif

            #ifdef EFFECT_SSGI_ENABLED
                vec3 sampleViewPos_gi = viewPos + vec3(offset_gi, 0.0);
                vec3 sampleClipPos_gi = unproject(ap.camera.projection, sampleViewPos_gi) * 0.5 + 0.5;

                bool skip_gi = false;
                if (clamp(sampleClipPos_gi.xy, 0.0, 1.0) != sampleClipPos_gi.xy) skip_gi = true;
                if (all(lessThan(abs(sampleClipPos_gi.xy - uv), pixelSize))) skip_gi = true;

                float sampleClipDepth_gi = textureLod(solidDepthTex, sampleClipPos_gi.xy, 0.0).r;
                if (sampleClipDepth_gi >= 1.0) skip_gi = true;

                if (!skip_gi) {
                    vec3 sampleColor = textureLod(texFinalPrevious, sampleClipPos_gi.xy, 0).rgb;

                    sampleClipPos_gi.z = sampleClipDepth_gi;
                    sampleViewPos_gi = unproject(ap.camera.projectionInv, sampleClipPos_gi * 2.0 - 1.0);

                    float gi_weight = 1.0;
                    if (abs(sampleViewPos_gi.z - viewPos.z) > max_radius_gi) gi_weight = 0.0;

                    #ifdef SSGIAO_TRACE_ENABLED
                        else {
                            vec3 traceRay = sampleClipPos_gi - clipPos;
                            vec3 traceStep = traceRay / (SSGIAO_TRACE_SAMPLES+1);
                            vec3 tracePos = clipPos;

                            for (int t = 0; t < SSGIAO_TRACE_SAMPLES; t++) {
                                tracePos += traceStep;
                                float traceSampleDepth = textureLod(solidDepthTex, tracePos.xy, 0.0).r;

                                if (tracePos.z >= traceSampleDepth) {
                                    gi_weight = 0.0;
                                    break;
                                }
                            }
                        }
                    #endif

                    vec3 diff = sampleViewPos_gi - viewPos;
                    float sampleDist = length(diff);
                    vec3 sampleNormal = diff / sampleDist;

                    float sampleNoLm = max(dot(viewNormal, sampleNormal), 0.0);

                     gi_weight *= 1.0 / (1.0 + sampleDist);

//                    gi_weight *= 1.0 - saturate(sampleDist / max_radius_gi);
                    illumination += sampleColor * sampleNoLm * gi_weight;
                }
            #endif
        }

        occlusion = occlusion / max(maxWeight, 1.0);
        //illumination = illumination / max(maxWeight, 1.0);
    }

    occlusion *= 3.0;
//    illumination *= 3.0;

    vec3 gi = illumination;
    float ao = 1.0 - min(occlusion, 1.0);
    // ao = ao*ao;

    out_GI_AO = vec4(gi, ao);
}
