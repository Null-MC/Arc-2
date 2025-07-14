#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 16, local_size_y = 16) in;

layout(rgba16f) uniform image2D imgScatterFinal;
layout(rgba16f) uniform image2D imgTransmitFinal;

uniform sampler2D TEX_SCATTER;
uniform sampler2D TEX_TRANSMIT;
uniform sampler2D TEX_DEPTH;

#include "/lib/common.glsl"
#include "/lib/sampling/depth.glsl"

#if LIGHTING_VL_RES == 2
    const int sharedBufferRes = 4+2;
#elif LIGHTING_VL_RES == 1
    const int sharedBufferRes = 8+2;
#endif

const int sharedBufferSize = _pow2(sharedBufferRes);

shared vec3 sharedScatterBuffer[sharedBufferSize];
shared vec3 sharedTransmitBuffer[sharedBufferSize];
shared float sharedDepthBuffer[sharedBufferSize];

const int uv_scale = int(exp2(LIGHTING_VL_RES));


void populateSharedBuffer() {
    uint i_base = uint(gl_LocalInvocationIndex);
    if (i_base >= sharedBufferSize) return;

    ivec2 uv_base = ivec2(gl_WorkGroupID.xy * gl_WorkGroupSize.xy);
    ivec2 uv_shared_base = uv_base / uv_scale;

    ivec2 uv_i = ivec2(
        i_base % sharedBufferRes,
        i_base / sharedBufferRes
    );

    ivec2 uv = uv_base + (uv_i-1) * uv_scale;
    ivec2 uv_shared = uv_shared_base + uv_i - 1;

    float depthL = ap.camera.far;
    vec3 scatterFinal = vec3(0.0);
    vec3 transmitFinal = vec3(1.0);

    if (all(greaterThanEqual(uv, ivec2(0))) && all(lessThan(uv, ivec2(ap.game.screenSize + 0.5)))) {
        scatterFinal = texelFetch(TEX_SCATTER, uv_shared, 0).rgb;
        transmitFinal = texelFetch(TEX_TRANSMIT, uv_shared, 0).rgb;

        float depth = texelFetch(TEX_DEPTH, uv, 0).r;
        depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);
    }

    sharedScatterBuffer[i_base] = scatterFinal;
    sharedTransmitBuffer[i_base] = transmitFinal;
    sharedDepthBuffer[i_base] = depthL;
}

void getNearestValues(const in float depthL, out vec3 scatterFinal, out vec3 transmitFinal) {
    ivec2 uv_base = ivec2(gl_LocalInvocationID.xy) / uv_scale + 1;

    float nearestDiff = 999.9;
    scatterFinal = vec3(0.0);
    transmitFinal = vec3(1.0);

    for (int iy = -1; iy <= 1; iy++) {
        for (int ix = -1; ix <= 1; ix++) {
            ivec2 uv_shared = uv_base + ivec2(ix, iy);
            int i_shared = uv_shared.y * sharedBufferRes + uv_shared.x;

            float sampleDepthL = sharedDepthBuffer[i_shared];
            float depthDiff = abs(sampleDepthL - depthL) + length(vec2(ix, iy));

            if (depthDiff < nearestDiff) {
                nearestDiff = depthDiff;

                scatterFinal = sharedScatterBuffer[i_shared];
                transmitFinal = sharedTransmitBuffer[i_shared];
            }
        }
    }
}


void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);

    populateSharedBuffer();

    groupMemoryBarrier();
    memoryBarrierShared();
    barrier();

	if (any(greaterThanEqual(uv, ivec2(ap.game.screenSize)))) return;

    float depth = texelFetch(TEX_DEPTH, ivec2(gl_GlobalInvocationID.xy), 0).r;
    float depthL = linearizeDepth(depth, ap.camera.near, ap.camera.far);

    vec3 scatterFinal, transmitFinal;
	getNearestValues(depthL, scatterFinal, transmitFinal);

	imageStore(imgScatterFinal, uv, vec4(scatterFinal, 1.0));
    imageStore(imgTransmitFinal, uv, vec4(transmitFinal, 1.0));
}
