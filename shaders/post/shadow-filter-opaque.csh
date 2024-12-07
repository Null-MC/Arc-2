#version 430 core

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

const int sharedBufferRes = 20;
const int sharedBufferSize = sharedBufferRes*sharedBufferRes;

shared float gaussianBuffer[5];
shared float sharedShadowBuffer[sharedBufferSize];
shared float sharedDepthBuffer[sharedBufferSize];

layout(r16f) uniform image2D imgShadow_final;

uniform sampler2D texShadow;
uniform sampler2D solidDepthTex;


#include "/lib/common.glsl"
#include "/lib/depth.glsl"
#include "/lib/gaussian.glsl"


const float g_sigmaXY = 3.0;
const float g_sigmaV = 3.0;

void populateSharedBuffer() {
    if (gl_LocalInvocationIndex < 5)
        gaussianBuffer[gl_LocalInvocationIndex] = Gaussian(g_sigmaXY, abs(gl_LocalInvocationIndex - 2));
    
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
        float shadow = 1.0;
	    if (all(greaterThanEqual(uv, ivec2(0))) && all(lessThan(uv, ivec2(screenSize + 0.5)))) {
	    	shadow = texelFetch(texShadow, uv, 0).r;
	    	float depth = texelFetch(solidDepthTex, uv, 0).r;
	    	depthL = linearizeDepth(depth, nearPlane, farPlane);
	    }

    	sharedShadowBuffer[i_shared] = shadow;
    	sharedDepthBuffer[i_shared] = depthL;
    }
}

float sampleSharedBuffer(const in float depthL) {
    ivec2 uv_base = ivec2(gl_LocalInvocationID.xy) + 2;

    float total = 0.0;
    float accum = 0.0;
    
    for (int iy = 0; iy < 5; iy++) {
        float fy = gaussianBuffer[iy];

        for (int ix = 0; ix < 5; ix++) {
            float fx = gaussianBuffer[ix];
            
            ivec2 uv_shared = uv_base + ivec2(ix, iy) - 2;
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            float sampleValue = sharedShadowBuffer[i_shared];
            float sampleDepthL = sharedDepthBuffer[i_shared];
            
            float depthDiff = abs(sampleDepthL - depthL);
            float fv = Gaussian(g_sigmaV, depthDiff);
            
            float weight = fx*fy*fv;
            accum += weight * sampleValue;
            total += weight;
        }
    }
    
    if (total <= EPSILON) return 1.0;
    return accum / total;
}


void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    populateSharedBuffer();
    barrier();

	if (any(greaterThanEqual(uv, ivec2(screenSize)))) return;

    ivec2 uv_shared = ivec2(gl_LocalInvocationID.xy) + 2;
    int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;
	float depthL = sharedDepthBuffer[i_shared];

	float shadow = sampleSharedBuffer(depthL);
	imageStore(imgShadow_final, uv, vec4(shadow));
}
