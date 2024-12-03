#version 430 core

layout (local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

const vec2 workGroups = ivec2(1, 1, 1);

layout(r32ui) uniform image2D imgHistogram;
layout(r32f) uniform image2D imgExposure;

#define GROUP_SIZE 256

shared uint histogramShared[GROUP_SIZE];


void main() {
	// Get the count from the histogram buffer
	uint countForThisBin = imageLoad(histogram, ivec2(localIndex, 0)).r;
	histogramShared[localIndex] = countForThisBin * localIndex;

	barrier();

	// Reset the count stored in the buffer in anticipation of the next pass
	imageStore(histogram, ivec2(localIndex, 0), uvec4(0));

	// This loop will perform a weighted count of the luminance range
	UNROLL
	for (uint cutoff = (GROUP_SIZE >> 1); cutoff > 0; cutoff >>= 1) {
		if (uint(localIndex) < cutoff) {
			histogramShared[localIndex] += histogramShared[localIndex + cutoff];
		}

		barrier();
	}

	// We only need to calculate this once, so only a single thread is needed.
	if (threadIndex == 0) {
		// Here we take our weighted sum and divide it by the number of pixels
		// that had luminance greater than zero (since the index == 0, we can
		// use countForThisBin to find the number of black pixels)
		float weightedLogAverage = (histogramShared[0] / max(numPixels - float(countForThisBin), 1.0)) - 1.0;

		// Map from our histogram space to actual luminance
		float weightedAvgLum = exp2(((weightedLogAverage / 254.0) * logLumRange) + minLogLum);

		// The new stored value will be interpolated using the last frames value
		// to prevent sudden shifts in the exposure.
		float lumLastFrame = imageLoad(s_target, ivec2(0, 0)).x;
		float adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeCoeff;

		imageStore(imgExposure, ivec2(0, 0), vec4(adaptedLum, 0.0, 0.0, 0.0));
	}
}
