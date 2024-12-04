#version 430 core

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(rgba16f) uniform readonly image2D imgFinal;
layout(r32ui) uniform uimage2D imgHistogram;

shared uint histogramShared[256];

#include "/lib/common.glsl"
#include "/lib/exposure.glsl"


uint colorToBin(const in vec3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	// Convert our RGB value to Luminance, see note for RGB_TO_LUM macro above
	float lum = luminance(hdrColor);

	// Avoid taking the log of zero
	if (lum < EPSILON) return 0u;

	// Calculate the log_2 luminance and express it as a value in [0.0, 1.0]
	// where 0.0 represents the minimum luminance, and 1.0 represents the max.
	float logLum = clamp((log2(lum) - minLogLum) * inverseLogLumRange, 0.0, 1.0);

	// Map [0, 1] to [1, 255]. The zeroth bin is handled by the epsilon check above.
	return uint(logLum * 254.0 + 1.0);
}

void main() {
	// Initialize the bin for this thread to 0
	histogramShared[gl_LocalInvocationIndex] = 0u;
	barrier();

	// uvec2 dim = imageSize(imgFinal).xy;

	// Ignore threads that map to areas beyond the bounds of our HDR image
	if (all(lessThan(gl_GlobalInvocationID.xy, ivec2(screenSize)))) {
		vec3 hdrColor = imageLoad(imgFinal, ivec2(gl_GlobalInvocationID.xy)).rgb;
		uint binIndex = colorToBin(hdrColor, Exposure_minLogLum, Exposure_logLumRange);

		atomicAdd(histogramShared[binIndex], 1u);
	}

	barrier();

	// Technically there's no chance that two threads write to the same bin here,
	// but different work groups might! So we still need the atomic add.
	imageAtomicAdd(imgHistogram, ivec2(gl_LocalInvocationIndex, 0), histogramShared[gl_LocalInvocationIndex]);

	// barrier();
}
