#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

const float AccumulationMax_Diffuse = 60.0;
const float AccumulationMax_Specular = 30.0;

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

//const int sharedBufferRes = 20;
//const int sharedBufferSize = sharedBufferRes*sharedBufferRes;

//shared float gaussianBuffer[5];
//shared vec3 sharedOcclusionBuffer[sharedBufferSize];
//shared float sharedDepthBuffer[sharedBufferSize];

layout(rgba16f) uniform writeonly image2D IMG_ACCUM_DIFFUSE;
layout(rgba16f) uniform writeonly image2D IMG_ACCUM_SPECULAR;
layout(rgba16f) uniform writeonly image2D IMG_ACCUM_POSITION;
layout(rgba16f) uniform writeonly image2D IMG_ACCUM_DIFFUSE_ALT;
layout(rgba16f) uniform writeonly image2D IMG_ACCUM_SPECULAR_ALT;
layout(rgba16f) uniform writeonly image2D IMG_ACCUM_POSITION_ALT;

#ifdef EFFECT_SSAO_ENABLED
    layout(r16f) uniform writeonly image2D IMG_ACCUM_OCCLUSION;
    layout(r16f) uniform writeonly image2D IMG_ACCUM_OCCLUSION_ALT;
#endif

uniform sampler2D TEX_DEPTH;
uniform usampler2D TEX_DEFERRED_DATA;

uniform sampler2D TEX_ACCUM_DIFFUSE;
uniform sampler2D TEX_ACCUM_SPECULAR;
uniform sampler2D TEX_ACCUM_POSITION;
uniform sampler2D TEX_ACCUM_DIFFUSE_ALT;
uniform sampler2D TEX_ACCUM_SPECULAR_ALT;
uniform sampler2D TEX_ACCUM_POSITION_ALT;

#if defined(EFFECT_SSAO_ENABLED) || defined(EFFECT_SSGI_ENABLED)
    uniform sampler2D TEX_SSGIAO;
#endif

#ifdef EFFECT_SSAO_ENABLED
    uniform sampler2D TEX_ACCUM_OCCLUSION;
    uniform sampler2D TEX_ACCUM_OCCLUSION_ALT;
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#endif

#include "/lib/common.glsl"
#include "/lib/depth.glsl"
#include "/lib/gaussian.glsl"
#include "/lib/sampling/catmull-rom.glsl"


const float g_sigmaXY = 1.0;
const float g_sigmaV = 0.002;

//void populateSharedBuffer() {
//    if (gl_LocalInvocationIndex < 5)
//        gaussianBuffer[gl_LocalInvocationIndex] = Gaussian(g_sigmaXY, abs(gl_LocalInvocationIndex - 2));
//
//    uint i_base = uint(gl_LocalInvocationIndex) * 2u;
//    if (i_base >= sharedBufferSize) return;
//
//    ivec2 uv_base = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy) - 2;
//
//    for (uint i = 0u; i < 2u; i++) {
//        uint i_shared = i_base + i;
//        if (i_shared >= sharedBufferSize) break;
//
//        ivec2 uv_i = ivec2(
//            i_shared % sharedBufferRes,
//            i_shared / sharedBufferRes
//        );
//
//        ivec2 uv = uv_base + uv_i;
//
//        float depthL = ap.camera.far;
//        vec3 ssgi = vec3(0.0);
//        if (all(greaterThanEqual(uv, ivec2(0))) && all(lessThan(uv, ivec2(ap.game.screenSize + 0.5)))) {
//            float depth = texelFetch(TEX_DEPTH, uv/2*2+1, 0).r;
//            depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
//
//            #ifdef EFFECT_SSGI_ENABLED
//                ssgi = texelFetch(TEX_SSGIAO, uv/2, 0).rgb;
//            #endif
//        }
//
//        sharedOcclusionBuffer[i_shared] = ssgi;
//        sharedDepthBuffer[i_shared] = depthL;
//    }
//}

//vec3 sampleSharedBuffer(const in float depthL) {
//    ivec2 uv_base = ivec2(gl_LocalInvocationID.xy) + 2;
//
//    float total = 0.0;
//    vec3 accum = vec3(0.0);
//
//    for (int iy = 0; iy < 5; iy++) {
//        float fy = gaussianBuffer[iy];
//
//        for (int ix = 0; ix < 5; ix++) {
//            float fx = gaussianBuffer[ix];
//
//            ivec2 uv_shared = uv_base + ivec2(ix, iy) - 2;
//            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;
//
//            vec3 sampleValue = sharedOcclusionBuffer[i_shared];
//            float sampleDepthL = sharedDepthBuffer[i_shared];
//
//            float depthDiff = abs(sampleDepthL - depthL);// * 1000.0;
//            float fv = Gaussian(g_sigmaV, depthDiff);
//
//            float weight = fx*fy*fv;
//            accum += weight * sampleValue;
//            total += weight;
//        }
//    }
//
//    if (total <= EPSILON) return vec3(0.0);
//    return accum / total;
//}

void main() {
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (iuv + 0.5) / ap.game.screenSize;

//    #ifdef EFFECT_SSGI_ENABLED
//        populateSharedBuffer();
//        barrier();
//    #endif

    if (any(greaterThanEqual(iuv, ivec2(ap.game.screenSize)))) return;

    //ivec2 uv_shared = ivec2(gl_LocalInvocationID.xy) + 2;
    //int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;
    // float depthL = sharedDepthBuffer[i_shared];


    // vec2 uv2 = uv;
    // uv2 += getJitterOffset(ap.time.frames);

    float depth = texelFetch(TEX_DEPTH, iuv, 0).r;
    uint data_g = texelFetch(TEX_DEFERRED_DATA, iuv, 0).g;

    // TODO: add velocity buffer
    vec3 velocity = vec3(0.0); //textureLod(BUFFER_VELOCITY, uv, 0).xyz;

    vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;

    vec3 viewPos = unproject(ap.camera.projectionInv, clipPos);

    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

    vec3 localPosPrev = localPos - velocity + (ap.camera.pos - ap.temporal.pos);

    vec3 viewPosPrev = mul3(ap.temporal.view, localPosPrev);

    vec3 clipPosPrev = unproject(ap.temporal.projection, viewPosPrev);

    vec2 uvLast = clipPosPrev.xy * 0.5 + 0.5;


    bool altFrame = (ap.time.frames % 2) == 1;

    vec3 previousDiffuse, previousSpecular;
    vec4 localPosLast;

    vec2 rtBufferSize = 0.5 * ap.game.screenSize;

    if (altFrame) {
        previousDiffuse = sample_CatmullRom_RGBA(TEX_ACCUM_DIFFUSE, uvLast, rtBufferSize).rgb;
        previousSpecular = sample_CatmullRom_RGBA(TEX_ACCUM_SPECULAR, uvLast, rtBufferSize).rgb;
        localPosLast = textureLod(TEX_ACCUM_POSITION, uvLast, 0);
    }
    else {
        previousDiffuse = sample_CatmullRom_RGBA(TEX_ACCUM_DIFFUSE_ALT, uvLast, rtBufferSize).rgb;
        previousSpecular = sample_CatmullRom_RGBA(TEX_ACCUM_SPECULAR_ALT, uvLast, rtBufferSize).rgb;
        localPosLast = textureLod(TEX_ACCUM_POSITION_ALT, uvLast, 0);
    }

    #ifdef EFFECT_SSAO_ENABLED
        vec2 aoBufferSize = 0.5 * ap.game.screenSize;

        float previousOcclusion;
        if (altFrame) {
            previousOcclusion = sample_CatmullRom(TEX_ACCUM_OCCLUSION, uvLast, aoBufferSize);
        }
        else {
            previousOcclusion = sample_CatmullRom(TEX_ACCUM_OCCLUSION_ALT, uvLast, aoBufferSize);
        }
    #endif

    float depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);

    float offsetThreshold = depthL * 0.04;

    float counterF = 1.0;
    if (saturate(uvLast) != uvLast) counterF = 0.0;
    if (distance(localPosPrev, localPosLast.xyz) > offsetThreshold) counterF = 0.0;

    float counter = localPosLast.w * counterF + 1.0;

    vec3 diffuse = vec3(0.0);
    vec3 specular = vec3(0.0);

    #if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
        diffuse = textureLod(texDiffuseRT, uv, 0).rgb;
        specular = textureLod(texSpecularRT, uv, 0).rgb;

        if (uv.x > 0.5) {
            vec2 rtPixelSize = 1.0 / rtBufferSize;

            vec3 a = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(-2.0, +2.0), uv), 0).rgb;
            vec3 b = textureLod(texDiffuseRT, fma(rtPixelSize, vec2( 0.0, +2.0), uv), 0).rgb;
            vec3 c = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(+2.0, +2.0), uv), 0).rgb;

            vec3 d = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(-2.0, 0.0), uv), 0).rgb;
            vec3 e = textureLod(texDiffuseRT, fma(rtPixelSize, vec2( 0.0, 0.0), uv), 0).rgb;
            vec3 f = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(+2.0, 0.0), uv), 0).rgb;

            vec3 g = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(-2.0, -2.0), uv), 0).rgb;
            vec3 h = textureLod(texDiffuseRT, fma(rtPixelSize, vec2( 0.0, -2.0), uv), 0).rgb;
            vec3 i = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(+2.0, -2.0), uv), 0).rgb;

            vec3 j = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(-1.0, +1.0), uv), 0).rgb;
            vec3 k = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(+1.0, +1.0), uv), 0).rgb;
            vec3 l = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(-1.0, -1.0), uv), 0).rgb;
            vec3 m = textureLod(texDiffuseRT, fma(rtPixelSize, vec2(+1.0, -1.0), uv), 0).rgb;

            vec3 blurColor = e         * 0.125;
            blurColor     += (a+c+g+i) * 0.03125;
            blurColor     += (b+d+f+h) * 0.0625;
            blurColor     += (j+k+l+m) * 0.125;

            diffuse = mix(diffuse, blurColor, 1.0 / counter);
        }
    #endif

//    #ifdef EFFECT_SSGI_ENABLED
//        diffuse += sampleSharedBuffer(depthL);
//    #endif

    #ifdef EFFECT_SSAO_ENABLED
        float occlusion = textureLod(TEX_SSGIAO, uv, 0).a;
    #endif

    float roughness = unpackUnorm4x8(data_g).x;
    float roughL = _pow2(roughness);

    float diffuseCounter = clamp(counter, 1.0, 1.0 + AccumulationMax_Diffuse);
    vec3 diffuseFinal = mix(previousDiffuse.rgb, diffuse, 1.0 / diffuseCounter);

    float specularCounter = clamp(counter, 1.0, 1.0 + AccumulationMax_Specular * roughL);
    vec3 specularFinal = mix(previousSpecular.rgb, specular, 1.0 / specularCounter);

    diffuseFinal = clamp(diffuseFinal, 0.0, 65000.0);
    specularFinal = clamp(specularFinal, 0.0, 65000.0);

    #ifdef EFFECT_SSAO_ENABLED
        //float occlusionCounter = clamp(counter, 1.0, 1.0 + AccumulationMax_Diffuse * roughL);
        float occlusionFinal = mix(previousOcclusion, occlusion, 1.0 / diffuseCounter);

        occlusionFinal = saturate(occlusionFinal);
    #endif

    if (altFrame) {
        imageStore(IMG_ACCUM_DIFFUSE_ALT,  iuv, vec4(diffuseFinal, 1.0));
        imageStore(IMG_ACCUM_SPECULAR_ALT, iuv, vec4(specularFinal, 1.0));
        imageStore(IMG_ACCUM_POSITION_ALT, iuv, vec4(localPos, counter));
    }
    else {
        imageStore(IMG_ACCUM_DIFFUSE,  iuv, vec4(diffuseFinal, 1.0));
        imageStore(IMG_ACCUM_SPECULAR, iuv, vec4(specularFinal, 1.0));
        imageStore(IMG_ACCUM_POSITION, iuv, vec4(localPos, counter));
    }

    #ifdef EFFECT_SSAO_ENABLED
        if (altFrame) {
            imageStore(IMG_ACCUM_OCCLUSION_ALT,  iuv, vec4(vec3(occlusionFinal), 1.0));
        }
        else {
            imageStore(IMG_ACCUM_OCCLUSION,  iuv, vec4(vec3(occlusionFinal), 1.0));
        }
    #endif
}
