#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

shared uint sharedBlockMap[10*10*10];
shared uint sharedBlockMetaMap[10*10*10];
shared vec3 floodfillBuffer[10*10*10];

layout(rgba16f) uniform image3D imgFloodFill;
layout(rgba16f) uniform image3D imgFloodFill_alt;

uniform sampler3D texFloodFill;
uniform sampler3D texFloodFill_alt;

#include "/lib/common.glsl"

#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/voxel-block.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"

#include "/lib/utility/hsv.glsl"


const float LpvFalloff = 0.998;
const float LpvBlockRange = 1.0;
const ivec3 flattenShared = ivec3(1, 10, 100);

int getSharedCoord(ivec3 pos) {
	return sumOf(pos * flattenShared);
}

ivec3 GetVoxelFrameOffset() {
    vec3 posNow = GetVoxelCenter(ap.camera.pos, ap.camera.viewInv[2].xyz);
    vec3 posPrev = GetVoxelCenter(ap.temporal.pos, ap.temporal.viewInv[2].xyz);

    vec3 posLast = fract(posNow) + (ap.temporal.pos - posPrev) - (ap.camera.pos - posNow);
    return ivec3(floor(posLast));
}

vec3 sample_floodfill_prev(in ivec3 texCoord) {
	if (!IsInVoxelBounds(texCoord)) return vec3(0.0);

	bool altFrame = ap.time.frames % 2 == 1;

	vec3 lpvSample = altFrame
		? imageLoad(imgFloodFill, texCoord).rgb
		: imageLoad(imgFloodFill_alt, texCoord).rgb;

	vec3 hsv = RgbToHsv(lpvSample);
	hsv.z = exp2(hsv.z * LpvBlockRange) - 1.0;
	lpvSample = HsvToRgb(hsv);

	return lpvSample;
}

void populateShared() {
	uint i1 = uint(gl_LocalInvocationIndex) * 2u;
	if (i1 >= 1000u) return;

	uint i2 = i1 + 1u;
	ivec3 workGroupOffset = ivec3(gl_WorkGroupID * gl_WorkGroupSize) - 1;

	ivec3 pos1 = workGroupOffset + ivec3(i1 / flattenShared) % 10;
	ivec3 pos2 = workGroupOffset + ivec3(i2 / flattenShared) % 10;

	ivec3 voxelFrameOffset = GetVoxelFrameOffset();
	floodfillBuffer[i1] = sample_floodfill_prev(pos1 - voxelFrameOffset);
	floodfillBuffer[i2] = sample_floodfill_prev(pos2 - voxelFrameOffset);

	uint blockId1 = 0u;
	uint blockId2 = 0u;
	uint blockMeta1 = 0u;
	uint blockMeta2 = 0u;

	if (IsInVoxelBounds(pos1)) {
		blockId1 = SampleVoxelBlock(pos1);

		if (blockId1 > 0u)
			blockMeta1 = iris_getMetadata(blockId1);
	}

	if (IsInVoxelBounds(pos2)) {
		blockId2 = SampleVoxelBlock(pos2);

		if (blockId2 > 0u)
			blockMeta2 = iris_getMetadata(blockId2);
	}

	sharedBlockMap[i1] = blockId1;
	sharedBlockMap[i2] = blockId2;

	sharedBlockMetaMap[i1] = blockMeta1;
	sharedBlockMetaMap[i2] = blockMeta2;
}

vec3 sampleFloodfillShared(ivec3 pos, uint mask_index) {
	int shared_index = getSharedCoord(pos);
//	uint blockMeta = sharedBlockMetaMap[shared_index];
//	uint wMask = bitfieldExtract(blockMeta, int(mask_index), 1);
	return floodfillBuffer[shared_index];// * wMask;
}

vec3 mixNeighbours(const in ivec3 fragCoord, const in uint mask) {
	uvec3 m1 = 1u - (uvec3(mask) >> uvec3(BLOCK_FACE_WEST, BLOCK_FACE_UP, BLOCK_FACE_NORTH)) & uvec3(1u);
	uvec3 m2 = 1u - (uvec3(mask) >> uvec3(BLOCK_FACE_EAST, BLOCK_FACE_DOWN, BLOCK_FACE_SOUTH)) & uvec3(1u);

	vec3 nX1 = sampleFloodfillShared(fragCoord + ivec3(-1,  0,  0), BLOCK_FACE_EAST) * m1.x;
	vec3 nX2 = sampleFloodfillShared(fragCoord + ivec3( 1,  0,  0), BLOCK_FACE_WEST) * m2.x;
	vec3 nY1 = sampleFloodfillShared(fragCoord + ivec3( 0, -1,  0), BLOCK_FACE_DOWN) * m1.y;
	vec3 nY2 = sampleFloodfillShared(fragCoord + ivec3( 0,  1,  0), BLOCK_FACE_UP) * m2.y;
	vec3 nZ1 = sampleFloodfillShared(fragCoord + ivec3( 0,  0, -1), BLOCK_FACE_SOUTH) * m1.z;
	vec3 nZ2 = sampleFloodfillShared(fragCoord + ivec3( 0,  0,  1), BLOCK_FACE_NORTH) * m2.z;

	const float avgFalloff = (1.0/6.0) * LpvFalloff;
	return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
}


void main() {
	uvec3 chunkPos = gl_WorkGroupID * gl_WorkGroupSize;
	if (any(greaterThanEqual(chunkPos, VoxelBufferSize))) return;

	populateShared();
	barrier();

	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	if (any(greaterThanEqual(cellIndex, VoxelBufferSize))) return;

	bool altFrame = ap.time.frames % 2 == 1;

    //vec3 viewDir = ap.camera.viewInv[2].xyz;
    //vec3 voxelCenter = GetVoxelCenter(ap.camera.pos, viewDir);
    vec3 localPos = GetVoxelLocalPos(cellIndex) + 0.5;

	ivec3 localCellIndex = ivec3(gl_LocalInvocationID);
	int sharedCoord = getSharedCoord(localCellIndex + 1);
	uint blockId = sharedBlockMap[sharedCoord];

	bool isFullBlock = false;
	vec3 blockTint = vec3(1.0);
	vec3 lightColor = vec3(0.0);
	int lightRange = 0;

	if (blockId > 0u) {
		isFullBlock = iris_isFullBlock(blockId);

		lightColor = iris_getLightColor(blockId).rgb;
		lightColor = RgbToLinear(lightColor);

		lightRange = iris_getEmission(blockId);

		if (lightRange == 0) {
			// TODO: is this reliable?
			blockTint = lightColor;

//				uint meta = sharedBlockMetaMap[sharedCoord];
//				uint blocking = bitfieldExtract(meta, 10, 4);
//				blockTint *= 1.0 - blocking/16.0;
		}
	}

	vec3 accumLight = vec3(0.0);

	if (!isFullBlock) {
		uint faceMask = 0u;
		if (blockId > 0u)
			faceMask = sharedBlockMetaMap[sharedCoord];

		accumLight = mixNeighbours(localCellIndex + 1, faceMask) * blockTint;
	}

	if (lightRange > 0) {
		vec3 hsv = RgbToHsv(lightColor);
		hsv.z = exp2((1.0/15.0) * lightRange) - 1.0;
		accumLight += HsvToRgb(hsv);
	}

	vec3 hsv = RgbToHsv(accumLight);
	hsv.z = log2(hsv.z + 1.0) / LpvBlockRange;
	accumLight = HsvToRgb(hsv);

	if (altFrame) imageStore(imgFloodFill_alt, cellIndex, vec4(accumLight, 1.0));
	else imageStore(imgFloodFill, cellIndex, vec4(accumLight, 1.0));
}
