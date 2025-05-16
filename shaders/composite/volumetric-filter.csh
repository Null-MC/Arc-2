#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

layout(rgba16f) uniform image2D imgScatterFinal;
layout(rgba16f) uniform image2D imgTransmitFinal;

uniform sampler2D texScatterVL;
uniform sampler2D texTransmitVL;
uniform sampler2D TEX_DEPTH;

#include "/lib/common.glsl"
#include "/lib/sampling/depth.glsl"
#include "/lib/sampling/gaussian.glsl"

const int sharedBufferRes = 20;
const int sharedBufferSize = _pow2(sharedBufferRes);

shared float gaussianBuffer[5];
shared vec3 sharedScatterBuffer[sharedBufferSize];
shared vec3 sharedTransmitBuffer[sharedBufferSize];
shared float sharedDepthBuffer[sharedBufferSize];

const float g_sigmaXY = 9.0;
const float g_sigmaV = 0.1;

void populateSharedBuffer() {
    if (gl_LocalInvocationIndex < 5)
        gaussianBuffer[gl_LocalInvocationIndex] = Gaussian(g_sigmaXY, gl_LocalInvocationIndex - 2);
    
    uint i_base = uint(gl_LocalInvocationIndex) * 2u;
    if (i_base >= sharedBufferSize) return;

    ivec2 uv_base = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy) - 2;

    const int uv_scale = int(exp2(LIGHTING_VL_RES));

    for (uint i = 0u; i < 2u; i++) {
	    uint i_shared = i_base + i;
	    if (i_shared >= sharedBufferSize) break;
	    
    	ivec2 uv_i = ivec2(
            i_shared % sharedBufferRes,
            i_shared / sharedBufferRes
        );

	    ivec2 uv = uv_base + uv_i;

	    float depthL = ap.camera.far;
	    vec3 scatterFinal = vec3(0.0);
        vec3 transmitFinal = vec3(1.0);

	    if (all(greaterThanEqual(uv, ivec2(0))) && all(lessThan(uv, ivec2(ap.game.screenSize + 0.5)))) {
            scatterFinal = texelFetch(texScatterVL, uv/uv_scale, 0).rgb;
            transmitFinal = texelFetch(texTransmitVL, uv/uv_scale, 0).rgb;

	    	float depth = texelFetch(TEX_DEPTH, uv, 0).r;
	    	depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
	    }

    	sharedScatterBuffer[i_shared] = scatterFinal;
        sharedTransmitBuffer[i_shared] = transmitFinal;
    	sharedDepthBuffer[i_shared] = depthL;
    }
}

void sampleSharedBuffer(const in float depthL, out vec3 scatterFinal, out vec3 transmitFinal) {
    ivec2 uv_base = ivec2(gl_LocalInvocationID.xy) + 2;

    float total = 0.0;
    vec3 accumScatter = vec3(0.0);
    vec3 accumTransmit = vec3(0.0);

    for (int iy = -2; iy <= 2; iy++) {
        float fy = gaussianBuffer[iy+2];

        for (int ix = -2; ix <= 2; ix++) {
            float fx = gaussianBuffer[ix+2];
            
            ivec2 uv_shared = uv_base + ivec2(ix, iy);
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            vec3 sampleScatter = sharedScatterBuffer[i_shared];
            vec3 sampleTransmit = sharedTransmitBuffer[i_shared];
            float sampleDepthL = sharedDepthBuffer[i_shared];
            
            float fv = Gaussian(g_sigmaV, sampleDepthL - depthL);
            
            float weight = fx*fy*fv;
            accumScatter += weight * sampleScatter;
            accumTransmit += weight * sampleTransmit;
            total += weight;
        }
    }


    if (total <= EPSILON) {
        scatterFinal = vec3(0.0);
        transmitFinal = vec3(1.0);
    }
    else {
        scatterFinal = accumScatter / total;
        transmitFinal = accumTransmit / total;
    }
}


void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    populateSharedBuffer();
    barrier();

	if (any(greaterThanEqual(uv, ivec2(ap.game.screenSize)))) return;

    ivec2 uv_shared = ivec2(gl_LocalInvocationID.xy) + 2;
    int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;
	float depthL = sharedDepthBuffer[i_shared];

    vec3 scatterFinal, transmitFinal;
	sampleSharedBuffer(depthL, scatterFinal, transmitFinal);

	imageStore(imgScatterFinal, uv, vec4(scatterFinal, 1.0));
    imageStore(imgTransmitFinal, uv, vec4(transmitFinal, 1.0));
}
