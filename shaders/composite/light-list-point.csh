#version 430 core

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/settings.glsl"
#include "/lib/common.glsl"

#ifndef VOXEL_PROVIDED
	#include "/lib/buffers/voxel-block.glsl"
#endif

#include "/lib/buffers/light-list.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"
#include "/lib/voxel/light-list.glsl"


void main() {
	uint workGroupSize = gl_WorkGroupSize.x*gl_WorkGroupSize.y*gl_WorkGroupSize.z;
	uint workGroupIndex = gl_WorkGroupID.z*(gl_NumWorkGroups.x*gl_NumWorkGroups.y) + gl_WorkGroupID.y*(gl_NumWorkGroups.x) + gl_WorkGroupID.x;
	uint globalIndex = workGroupIndex * workGroupSize + gl_LocalInvocationIndex;

	if (globalIndex < POINT_LIGHT_MAX) {
		vec3 lightLocalPos = ap.point.pos[globalIndex];

		// get light bin index
		vec3 voxelPos = voxel_GetBufferPosition(lightLocalPos);
		ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
		int lightBinIndex = GetLightBinIndex(lightBinPos);

		// TODO: add light to bin
		//int neighborBinIndex = GetLightBinIndex(neighborBinPos);
		uint lightIndex = atomicAdd(LightBinMap[lightBinIndex].lightCount, 1u);

		if (lightIndex < RT_MAX_LIGHT_COUNT) {
			// TODO: set light data (to what?)
			//LightBinMap[lightBinIndex].lightList[lightIndex] = ?;
		}
	}
}
