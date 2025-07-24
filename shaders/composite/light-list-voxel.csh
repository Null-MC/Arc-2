#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"

#ifndef VOXEL_PROVIDED
	#include "/lib/buffers/voxel-block.glsl"
#endif

#include "/lib/buffers/light-list.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"
#include "/lib/voxel/light-list.glsl"


void main() {
	ivec3 voxelPos = ivec3(gl_GlobalInvocationID);
	uint voxelIndex = voxel_GetBufferIndex(voxelPos);
	uint blockId = SampleVoxelBlock(voxelPos);

	// skip if already exists in shadow light list
	ivec3 voxelBinPos = ivec3(floor((voxelPos) / LIGHT_BIN_SIZE));
	int voxelBinIndex = GetLightBinIndex(voxelBinPos);
	uint shadowLightCount = LightBinMap[voxelBinIndex].shadowLightCount;
	shadowLightCount = clamp(shadowLightCount, 0u, LIGHTING_SHADOW_BIN_MAX_COUNT);

	bool exists = false;
	for (int i = 0; i < shadowLightCount; i++) {
		if (LightBinMap[voxelBinIndex].lightList[i].voxelIndex == voxelIndex) {
			exists = true;
			break;
		}
	}

	if (blockId > 0u && !exists) {
		int lightRange = iris_getEmission(blockId);

		uint blockMapId = iris_getCustomId(blockId);
		if (blockMapId == BLOCK_LAVA) lightRange = 0;
		
		if (lightRange > 0) {
			uint lightIndex = atomicAdd(LightBinMap[voxelBinIndex].lightCount, 1u) + shadowLightCount;

			if (lightIndex < LIGHTING_SHADOW_BIN_MAX_COUNT) {
				LightBinMap[voxelBinIndex].lightList[lightIndex].voxelIndex = voxelIndex;
			}
		}
	}
}
