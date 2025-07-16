#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(r32ui) uniform uimage2D imgHistogram;

uniform sampler2D TEX_SRC;
uniform sampler2D handDepth;
uniform sampler2D mainDepthTex;

shared uint histogramShared[256];

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"


uint colorToBin(const in vec3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	float lum = luminance(hdrColor);
	if (lum < EPSILON) return 0u;

	float logLum = saturate((log2(lum) - minLogLum) * inverseLogLumRange);
	return uint(logLum * 254.0 + 1.0);
}

void main() {
	histogramShared[gl_LocalInvocationIndex] = 0u;
	barrier();

	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	if (all(lessThan(uv, ivec2(ap.game.screenSize)))) {
		vec3 hdrColor = texelFetch(TEX_SRC, ivec2(gl_GlobalInvocationID.xy), 0).rgb * BufferLumScale;

		// ignore if hand pixel
		// TODO: FIX THIS LATER! false-positive in water
//		float depthPreHand = textureLod(handDepth, uv, 0).r;
//		float depthPostHand = textureLod(mainDepthTex, uv, 0).r;
//		if (depthPostHand < depthPreHand) hdrColor = vec3(0.0);

		uint binIndex = colorToBin(hdrColor, Scene_PostExposureMin, Exposure_logLumRangeInv);

		atomicAdd(histogramShared[binIndex], 1u);
	}

	barrier();

	imageAtomicAdd(imgHistogram, ivec2(gl_LocalInvocationIndex, 0), histogramShared[gl_LocalInvocationIndex]);
}
