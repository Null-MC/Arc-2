#version 430 core

layout (local_size_x = 8, local_size_y = 8) in;

const vec2 workGroupsRender = vec2(1.0, 1.0);

layout(rgba16f) uniform readonly image2D imgFinal;
layout(r32ui) uniform image2D imgHistogram;

#define GROUP_SIZE 256

shared uint histogramShared[GROUP_SIZE];


uint colorToBin(const in vec3 hdrColor, const in float minLogLum, const in float inverseLogLumRange) {
	// Convert our RGB value to Luminance, see note for RGB_TO_LUM macro above
	float lum = luminance(hdrColor);

	// Avoid taking the log of zero
	if (lum < EPSILON) return 0;

	// Calculate the log_2 luminance and express it as a value in [0.0, 1.0]
	// where 0.0 represents the minimum luminance, and 1.0 represents the max.
	float logLum = clamp((log2(lum) - minLogLum) * inverseLogLumRange, 0.0, 1.0);

	// Map [0, 1] to [1, 255]. The zeroth bin is handled by the epsilon check above.
	return uint(logLum * 254.0 + 1.0);
}

void main() {
	// Initialize the bin for this thread to 0
	histogramShared[gl_LocalInvocationIndex] = 0;
	barrier();

	uvec2 dim = imageSize(imgFinal).xy;

	// Ignore threads that map to areas beyond the bounds of our HDR image
	if (all(lessThan(gl_GlobalInvocationID.xy, dim.xy))) {
		vec3 hdrColor = imageLoad(imgFinal, ivec2(gl_GlobalInvocationID.xy)).xyz;
		uint binIndex = colorToBin(hdrColor, u_params.x, u_params.y);

		atomicAdd(histogramShared[binIndex], 1);
	}

	barrier();

	// Technically there's no chance that two threads write to the same bin here,
	// but different work groups might! So we still need the atomic add.
	imageAtomicAdd(imgHistogram, ivec2(gl_LocalInvocationIndex, 0), histogramShared[gl_LocalInvocationIndex]);
}
