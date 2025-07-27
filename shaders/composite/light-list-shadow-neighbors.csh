#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"

#include "/lib/buffers/light-list.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/light-list.glsl"


void tryAddNeighborLights(inout uint lightCount, const in int binIndex, const in ivec3 neighborBinPos) {
	int neighborBinIndex = GetLightBinIndex(neighborBinPos);
	uint neighborLightCount = clamp(LightBinMap[neighborBinIndex].shadowLightCount, 0u, LIGHTING_SHADOW_BIN_MAX_COUNT);

	ivec3 bin_min = neighborBinPos*LIGHT_BIN_SIZE;
	ivec3 bin_max = (neighborBinPos+1)*LIGHT_BIN_SIZE;

	for (uint i = 0u; i < neighborLightCount; i++) {
		PointLight lightRef = LightBinMap[neighborBinIndex].lightList[i];

		ap_PointLight light = iris_getPointLight(lightRef.shadowIndex);

		ivec3 lightVoxelPos = GetLightVoxelPos(lightRef.voxelIndex);

		float lightRange = iris_getEmission(light.block);
		lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);
		float lightRangeSq = _pow2(lightRange);

		// check light range
		ivec3 boxPos = clamp(lightVoxelPos, bin_min, bin_max);
		if (lengthSq(boxPos - lightVoxelPos) >= lightRangeSq) continue;

		uint lightIndex = lightCount;
		lightCount++;

		if (lightIndex < LIGHTING_SHADOW_BIN_MAX_COUNT) {
			LightBinMap[binIndex].lightList[lightIndex] = lightRef;
		}
	}
}

void main() {
	ivec3 lightBinPos = ivec3(gl_GlobalInvocationID);
	if (any(greaterThanEqual(lightBinPos, ivec3(LightBinGridSize)))) return;

	int binIndex = GetLightBinIndex(lightBinPos);
	uint lightCount = LightBinMap[binIndex].shadowLightCount;
	lightCount = clamp(lightCount, 0u, LIGHTING_SHADOW_BIN_MAX_COUNT);

	// TODO: rearrange loop to prioritize nearer bins
	for (int _z = -2; _z <= 2; _z++) {
		for (int _y = -2; _y <= 2; _y++) {
			for (int _x = -2; _x <= 2; _x++) {
				if (_x == 0 && _y == 0 && _z == 0) continue;

				ivec3 neighborBinPos = lightBinPos + ivec3(_x, _y, _z);
				if (any(lessThan(neighborBinPos, ivec3(0))) || any(greaterThanEqual(neighborBinPos, ivec3(LightBinGridSize)))) continue;

				tryAddNeighborLights(lightCount, binIndex, neighborBinPos);
			}
		}
	}

	LightBinMap[binIndex].lightCount = lightCount;
}
