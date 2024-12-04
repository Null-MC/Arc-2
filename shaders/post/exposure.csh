#version 430 core

layout (local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(r32ui) uniform uimage2D imgHistogram;
layout(r32ui) uniform uimage2D imgHistogram_debug;
layout(r16f) uniform image2D imgExposure;

shared uint histogramShared[256];

#include "/lib/common.glsl"
#include "/lib/exposure.glsl"


void main() {
	// Get the count from the histogram buffer
	uint countForThisBin = imageLoad(imgHistogram, ivec2(gl_LocalInvocationIndex, 0)).r;

	imageStore(imgHistogram_debug, ivec2(gl_LocalInvocationIndex, 0), uvec4(countForThisBin, 0.0, 0.0, 0.0));

	histogramShared[gl_LocalInvocationIndex] = countForThisBin * gl_LocalInvocationIndex;

	barrier();

	// Reset the count stored in the buffer in anticipation of the next pass
	imageStore(imgHistogram, ivec2(gl_LocalInvocationIndex, 0), uvec4(0u));

	// This loop will perform a weighted count of the luminance range
	for (uint cutoff = (256u >> 1u); cutoff > 0u; cutoff >>= 1u) {
		if (uint(gl_LocalInvocationIndex) < cutoff) {
			histogramShared[gl_LocalInvocationIndex] += histogramShared[gl_LocalInvocationIndex + cutoff];
		}

		barrier();
	}

	// We only need to calculate this once, so only a single thread is needed.
	if (gl_LocalInvocationIndex == 0) {
		// Here we take our weighted sum and divide it by the number of pixels
		// that had luminance greater than zero (since the index == 0, we can
		// use countForThisBin to find the number of black pixels)
		// float weightedLogAverage = (histogramShared[0] / max(Exposure_numPixels - float(countForThisBin), 1.0)) - 1.0;
		float weightedLogAverage = (histogramShared[0] / max(Exposure_numPixels - float(countForThisBin), 1.0)) / 255.0;
		// float weightedLogAverage = float(histogramShared[0]) / max(Exposure_numPixels, 1.0) / 255.0;

		// Map from our histogram space to actual luminance
		// float weightedAvgLum = exp2(((weightedLogAverage / 254.0) * Exposure_logLumRange) + Exposure_minLogLum);
		// imageStore(imgExposure, ivec2(0, 0), vec4(weightedAvgLum));
		// return;

		// The new stored value will be interpolated using the last frames value
		// to prevent sudden shifts in the exposure.
		float lumLastFrame = imageLoad(imgExposure, ivec2(0, 0)).r;
		float adaptedLum = lumLastFrame + (weightedLogAverage - lumLastFrame) * Exposure_timeCoeff;

		imageStore(imgExposure, ivec2(0, 0), vec4(adaptedLum));
	}
}
