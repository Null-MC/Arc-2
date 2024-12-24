#version 430 core
#extension GL_NV_gpu_shader5: enable

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r32ui) uniform readonly uimage3D imgVoxelBlock;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/light-list.glsl"
// #include "/lib/buffers/triangle-list.glsl"

#include "/lib/voxel/voxel_common.glsl"
#include "/lib/voxel/light-list.glsl"


void main() {
	ivec3 voxelPos = ivec3(gl_GlobalInvocationID);
	uint blockId = imageLoad(imgVoxelBlock, voxelPos).r;

	if (blockId > 0u) {
		int lightRange = iris_getEmission(blockId);
		
		if (lightRange > 0) {
			ivec3 voxelBinMin = ivec3((voxelPos - lightRange) / LIGHT_BIN_SIZE);
			ivec3 voxelBinMax = ivec3((voxelPos + lightRange) / LIGHT_BIN_SIZE);

			uint voxelIndex = GetVoxelIndex(voxelPos);

			for (int z = voxelBinMin.z; z <= voxelBinMax.z; z++) {
				for (int y = voxelBinMin.y; y <= voxelBinMax.y; y++) {
					for (int x = voxelBinMin.x; x <= voxelBinMax.x; x++) {
						ivec3 neighborBinPos = ivec3(x, y, z);
						if (clamp(neighborBinPos, 0, LightBinGridSize) != neighborBinPos) continue;

						// TODO: box-sphere intersection check
						vec3 boxPos = clamp(voxelPos, neighborBinPos*LIGHT_BIN_SIZE, (neighborBinPos+1)*LIGHT_BIN_SIZE);
						if (lengthSq(boxPos - voxelPos) >= lightRange*lightRange) continue;

						int neighborBinIndex = GetLightBinIndex(neighborBinPos);
						uint lightIndex = atomicAdd(LightBinMap[neighborBinIndex].lightCount, 1u);

						if (lightIndex < LIGHT_BIN_MAX) {
							LightBinMap[neighborBinIndex].lightList[lightIndex] = voxelIndex;
						}
					}
				}
			}
		}
	}

	barrier();

	ivec3 globalBinPos = ivec3(gl_GlobalInvocationID) / LIGHT_BIN_SIZE;
	ivec3 localBinPos = ivec3(gl_GlobalInvocationID) - globalBinPos*LIGHT_BIN_SIZE;

	if (all(equal(localBinPos, ivec3(0)))) {
		int lightBinIndex = GetLightBinIndex(globalBinPos);
		atomicAdd(Scene_LightCount, LightBinMap[lightBinIndex].lightCount);

		// int triangleBinIndex = GetTriangleBinIndex(globalBinPos);
		// atomicAdd(Scene_TriangleCount, TriangleBinMap[binIndex].triangleCount);
	}
}
