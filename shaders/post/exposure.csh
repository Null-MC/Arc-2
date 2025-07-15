#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout (local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(r32ui) uniform uimage2D imgHistogram;

#ifdef DEBUG_EXPOSURE
	layout(r32ui) uniform uimage2D imgHistogram_debug;
#endif

shared uint histogramShared[256];

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"


void main() {
	ivec2 histogram_uv = ivec2(gl_LocalInvocationIndex, 0);

	uint countForThisBin = imageLoad(imgHistogram, histogram_uv).r;
	histogramShared[gl_LocalInvocationIndex] = countForThisBin * gl_LocalInvocationIndex;

	barrier();

	#ifdef DEBUG_EXPOSURE
		imageStore(imgHistogram_debug, histogram_uv, uvec4(countForThisBin));
	#endif

	imageStore(imgHistogram, histogram_uv, uvec4(0u));

	// This loop will perform a weighted count of the luminance range
	for (uint cutoff = (256u >> 1u); cutoff > 0u; cutoff >>= 1u) {
		if (uint(gl_LocalInvocationIndex) < cutoff) {
			histogramShared[gl_LocalInvocationIndex] += histogramShared[gl_LocalInvocationIndex + cutoff];
		}

		barrier();
	}

	if (gl_LocalInvocationIndex == 0) {
		// Here we take our weighted sum and divide it by the number of pixels
		// that had luminance greater than zero (since the index == 0, we can
		// use countForThisBin to find the number of black pixels)
		float Exposure_numPixels = ap.game.screenSize.x * ap.game.screenSize.y;
		float nonBlackPixelCount = Exposure_numPixels - countForThisBin;
		float weightedLogAverage = (histogramShared[0] / max(nonBlackPixelCount, 1.0)) - 1.0;

		// Map from our histogram space to actual luminance
		float weightedAvgLum = exp2((weightedLogAverage/254.0 * Exposure_logLumRange) + Scene_PostExposureMin);
		float adaptedLum = weightedAvgLum;

		// do not mix if first rendered frame
		if (ap.time.frames != 0) {
			float timeF = 1.0 - exp(-max(Scene_PostExposureSpeed * ap.time.delta, 1.0e-12));

//			float lumLastFrame = clamp(Scene_AvgExposure, 0.0, 99999.0);
			float lumLastFrame = max(Scene_AvgExposure, 0.0);
			adaptedLum = lumLastFrame + (weightedAvgLum - lumLastFrame) * timeF;
		}

		Scene_AvgExposure = adaptedLum;
	}
}
