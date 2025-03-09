#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f) uniform readonly image2D imgFinal;
layout(r32ui) uniform uimage2D imgHistogram;

shared uint histogramShared[256];

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"


uint colorToBin(const in vec3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	float lum = luminance(hdrColor);
	if (lum < EPSILON) return 0u;

	float logLum = clamp((log2(lum) - minLogLum) * inverseLogLumRange, 0.0, 1.0);
	return uint(logLum * 254.0 + 1.0);
}

void main() {
	histogramShared[gl_LocalInvocationIndex] = 0u;
	barrier();

	if (all(lessThan(gl_GlobalInvocationID.xy, ivec2(ap.game.screenSize)))) {
		vec3 hdrColor = imageLoad(imgFinal, ivec2(gl_GlobalInvocationID.xy)).rgb;
		uint binIndex = colorToBin(hdrColor, Scene_PostExposureMin, Exposure_logLumRange);

		atomicAdd(histogramShared[binIndex], 1u);
	}

	barrier();

	imageAtomicAdd(imgHistogram, ivec2(gl_LocalInvocationIndex, 0), histogramShared[gl_LocalInvocationIndex]);
}
