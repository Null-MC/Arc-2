#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"

#include "/lib/buffers/light-list.glsl"

#ifndef VOXEL_PROVIDED
	#include "/lib/buffers/voxel-block.glsl"
#endif

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"
#include "/lib/voxel/light-list.glsl"


void main() {
	ivec3 lightBinPos = ivec3(gl_GlobalInvocationID);
	if (any(greaterThanEqual(lightBinPos, ivec3(LightBinGridSize)))) return;

	int lightBinIndex = GetLightBinIndex(lightBinPos);
	uint shadowLightCount = LightBinMap[lightBinIndex].shadowLightCount;
	uint lightCount = LightBinMap[lightBinIndex].lightCount;

	for (uint i = 0u; i < min(lightCount, LIGHTING_SHADOW_BIN_MAX_COUNT-shadowLightCount); i++) {
		uint i_offset = i + shadowLightCount;
//		uint lightIndex = LightBinMap[lightBinIndex].lightList[i_offset].shadowIndex;
//		uint lightBlockId = ap.point.block[lightIndex];
//		float lightRange = iris_getEmission(lightBlockId);
//		float lightRangeSq = _pow2(lightRange);

		uint voxelIndex = LightBinMap[lightBinIndex].lightList[i_offset].voxelIndex;
		ivec3 lightVoxelPos = GetLightVoxelPos(voxelIndex);
		uint lightBlockId = SampleVoxelBlock(lightVoxelPos);
		float lightRange = iris_getEmission(lightBlockId);
		float lightRangeSq = _pow2(lightRange);

		for (int _z = -2; _z <= 2; _z++) {
			for (int _y = -2; _y <= 2; _y++) {
				for (int _x = -2; _x <= 2; _x++) {
					if (_x == 0 && _y == 0 && _z == 0) continue;

					ivec3 neighborBinPos = lightBinPos + ivec3(_x, _y, _z);

					// check light range
					ivec3 boxPos = clamp(lightVoxelPos, neighborBinPos*LIGHT_BIN_SIZE, (neighborBinPos+1)*LIGHT_BIN_SIZE);
					bool isInRange = lengthSq(boxPos - lightVoxelPos) < lightRangeSq;

					if (isInRange && all(greaterThanEqual(neighborBinPos, ivec3(0))) && all(lessThan(neighborBinPos, ivec3(LightBinGridSize)))) {
						int neighborBinIndex = GetLightBinIndex(neighborBinPos);
						uint neighborLightIndex = atomicAdd(LightBinMap[neighborBinIndex].lightCount, 1u) + shadowLightCount;

						if (neighborLightIndex < LIGHTING_SHADOW_BIN_MAX_COUNT) {
							LightBinMap[neighborBinIndex].lightList[neighborLightIndex].voxelIndex = voxelIndex;
							//LightBinMap[neighborBinIndex].lightList[neighborLightIndex].shadowIndex = lightIndex;
						}
					}
				}
			}
		}

		// TODO: redo this with a linear loop that skips center without continue
	}
}
