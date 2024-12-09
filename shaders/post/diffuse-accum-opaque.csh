#version 430 core

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

const int sharedBufferRes = 20;
const int sharedBufferSize = sharedBufferRes*sharedBufferRes;

shared float gaussianBuffer[5];
shared vec3 sharedOcclusionBuffer[sharedBufferSize];
shared float sharedDepthBuffer[sharedBufferSize];

layout(rgba16f) uniform writeonly image2D imgDiffuseAccum;

uniform sampler2D solidDepthTex;
uniform sampler2D texDiffuseAccumPrevious;
uniform sampler2D texSSGIAO;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/depth.glsl"
#include "/lib/gaussian.glsl"


const float g_sigmaXY = 3.0;
const float g_sigmaV = 0.1;

void populateSharedBuffer() {
    if (gl_LocalInvocationIndex < 5)
        gaussianBuffer[gl_LocalInvocationIndex] = Gaussian(g_sigmaXY, gl_LocalInvocationIndex - 2);
    
    uint i_base = uint(gl_LocalInvocationIndex) * 2u;
    if (i_base >= sharedBufferSize) return;

    ivec2 uv_base = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy) - 2;

    for (uint i = 0u; i < 2u; i++) {
        uint i_shared = i_base + i;
        if (i_shared >= sharedBufferSize) break;
        
        ivec2 uv_i = ivec2(
            i_shared % sharedBufferRes,
            i_shared / sharedBufferRes
        );

        ivec2 uv = uv_base + uv_i;

        float depthL = farPlane;
        vec3 ssgi = vec3(0.0);
        if (all(greaterThanEqual(uv, ivec2(0))) && all(lessThan(uv, ivec2(screenSize + 0.5)))) {
            ssgi = texelFetch(texSSGIAO, uv/2, 0).rgb;
            float depth = texelFetch(solidDepthTex, uv, 0).r;
            depthL = linearizeDepth(depth, nearPlane, farPlane);
        }

        sharedOcclusionBuffer[i_shared] = ssgi;
        sharedDepthBuffer[i_shared] = depthL;
    }
}

vec3 sampleSharedBuffer(const in float depthL) {
    ivec2 uv_base = ivec2(gl_LocalInvocationID.xy) + 2;

    float total = 0.0;
    vec3 accum = vec3(0.0);
    
    for (int iy = 0; iy < 5; iy++) {
        float fy = gaussianBuffer[iy];

        for (int ix = 0; ix < 5; ix++) {
            float fx = gaussianBuffer[ix];
            
            ivec2 uv_shared = uv_base + ivec2(ix, iy) - 2;
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            vec3 sampleValue = sharedOcclusionBuffer[i_shared];
            float sampleDepthL = sharedDepthBuffer[i_shared];
            
            float depthDiff = sampleDepthL - depthL;
            float fv = Gaussian(g_sigmaV, depthDiff);
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    if (total <= EPSILON) return vec3(0.0);
    return accum / total;
}

vec3 getReprojectedClipPos(const in vec2 texcoord, const in float depth, const in vec3 velocity) {
    vec3 clipPos = vec3(texcoord, depth) * 2.0 - 1.0;

    vec3 viewPos = unproject(playerProjectionInverse, clipPos);

    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localPosPrev = localPos - velocity + (cameraPos - lastCameraPos);

    vec3 viewPosPrev = mul3(lastPlayerModelView, localPosPrev);

    vec3 clipPosPrev = unproject(lastPlayerProjection, viewPosPrev);

    return clipPosPrev * 0.5 + 0.5;
}

void main() {
    ivec2 iuv = ivec2(gl_GlobalInvocationID.xy);

    vec2 uv = (iuv + 0.5) / screenSize;

    populateSharedBuffer();
    barrier();

    if (any(greaterThanEqual(iuv, ivec2(screenSize)))) return;

    ivec2 uv_shared = ivec2(gl_LocalInvocationID.xy) + 2;
    int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;
    // float depthL = sharedDepthBuffer[i_shared];


    // vec2 uv2 = uv;
    // uv2 += getJitterOffset(frameCounter);

    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    // TODO: add velocity buffer
    vec3 velocity = vec3(0.0); //textureLod(BUFFER_VELOCITY, uv, 0).xyz;
    vec2 uvLast = getReprojectedClipPos(uv, depth, velocity).xy;

    vec4 previous = textureLod(texDiffuseAccumPrevious, uvLast, 0);

    if (clamp(uvLast, 0.0, 1.0) != uvLast) previous.a = 0.0;

    float depthL = linearizeDepth(depth, nearPlane, farPlane);

    vec3 diffuse = sampleSharedBuffer(depthL);

    // TODO: add RT diffuse lighting

    float counter = clamp(previous.a + 1.0, 1.0, 30.0);
    vec3 diffuseFinal = mix(previous.rgb, diffuse, 1.0 / counter);

    imageStore(imgDiffuseAccum, iuv, vec4(diffuseFinal, counter));
}
