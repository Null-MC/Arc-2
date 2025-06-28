#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"

#include "/lib/buffers/light-list.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/light-list.glsl"


void main() {
	uint workGroupSize = gl_WorkGroupSize.x*gl_WorkGroupSize.y*gl_WorkGroupSize.z;
	uint workGroupIndex = gl_WorkGroupID.z*(gl_NumWorkGroups.x*gl_NumWorkGroups.y) + gl_WorkGroupID.y*(gl_NumWorkGroups.x) + gl_WorkGroupID.x;
	uint globalIndex = workGroupIndex * workGroupSize + gl_LocalInvocationIndex;

	uint shadowIndex = globalIndex;
	if (shadowIndex < LIGHTING_SHADOW_MAX_COUNT) {
		vec3 lightLocalPos = ap.point.pos[shadowIndex].xyz;

		// get light bin index
		vec3 voxelPos = voxel_GetBufferPosition(lightLocalPos);
		if (voxel_isInBounds(voxelPos) && ap.point.block[shadowIndex] > 0) {
			ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
			int lightBinIndex = GetLightBinIndex(lightBinPos);

			// add light to bin
			uint lightIndex = atomicAdd(LightBinMap[lightBinIndex].shadowLightCount, 1u);

			if (lightIndex < LIGHTING_SHADOW_BIN_MAX_COUNT) {
				uint voxelIndex = voxel_GetBufferIndex(ivec3(floor(voxelPos)));

				LightBinMap[lightBinIndex].lightList[lightIndex].voxelIndex = voxelIndex;
				LightBinMap[lightBinIndex].lightList[lightIndex].shadowIndex = shadowIndex;

				#ifdef DEBUG_LIGHT_COUNT
					atomicAdd(Scene_LightCount, 1u);
				#endif
			}
		}
	}
}
