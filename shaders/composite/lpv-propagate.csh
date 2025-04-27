#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

shared uint sharedBlockMap[10*10*10];

#if LIGHTING_MODE == LIGHT_MODE_LPV
	shared vec3 floodfillBuffer[10*10*10];

	layout(rgba16f) uniform image3D imgFloodFill;
	layout(rgba16f) uniform image3D imgFloodFill_alt;
#endif


#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/voxel-block.glsl"

//#include "/lib/noise/hash.glsl"

#include "/lib/voxel/voxel_common.glsl"
#include "/lib/lpv/lpv_common.glsl"

#include "/lib/utility/hsv.glsl"


const float LpvFalloff = 0.998;
const float LpvBlockRange = 1.0;
const ivec3 flattenShared = ivec3(1, 10, 100);

int getSharedCoord(ivec3 pos) {
	return sumOf(pos * flattenShared);
}

ivec3 GetVoxelFrameOffset() {
    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 posNow = GetVoxelCenter(ap.camera.pos, viewDir);

    vec3 viewDirPrev = vec3(ap.temporal.view[0].z, ap.temporal.view[1].z, ap.temporal.view[2].z);
    vec3 posPrev = GetVoxelCenter(ap.temporal.pos, viewDirPrev);

    vec3 posLast = posNow + (ap.temporal.pos - ap.camera.pos) - (posPrev - posNow);

    return ivec3(posNow) - ivec3(posLast);
}

vec3 sample_floodfill_prev(in ivec3 texCoord) {
	if (!IsInVoxelBounds(texCoord)) return vec3(0.0);

	bool altFrame = ap.time.frames % 2 == 1;

	vec3 lpvSample = altFrame
		? imageLoad(imgFloodFill, texCoord).rgb
		: imageLoad(imgFloodFill_alt, texCoord).rgb;

	//lpvSample = RgbToLinear(lpvSample);

	vec3 hsv = RgbToHsv(lpvSample);
	hsv.z = pow(6.0, hsv.z * LpvBlockRange) - 1.0;
	lpvSample = HsvToRgb(hsv);

	return lpvSample;
}

void populateShared(const in ivec3 voxelFrameOffset) {
	uint i1 = uint(gl_LocalInvocationIndex) * 2u;
	if (i1 >= 1000u) return;

	uint i2 = i1 + 1u;
	ivec3 workGroupOffset = ivec3(gl_WorkGroupID * gl_WorkGroupSize) - 1;

	ivec3 pos1 = workGroupOffset + ivec3(i1 / flattenShared) % 10;
	ivec3 pos2 = workGroupOffset + ivec3(i2 / flattenShared) % 10;

	ivec3 lpvPos1 = voxelFrameOffset + pos1;
	ivec3 lpvPos2 = voxelFrameOffset + pos2;

	floodfillBuffer[i1] = sample_floodfill_prev(lpvPos1);
	floodfillBuffer[i2] = sample_floodfill_prev(lpvPos2);

	uint blockId1 = 0u;
	uint blockId2 = 0u;

	if (IsInVoxelBounds(pos1)) {
		blockId1 = imageLoad(imgVoxelBlock, pos1).r;
	}

	if (IsInVoxelBounds(pos2)) {
		blockId2 = imageLoad(imgVoxelBlock, pos2).r;
	}

	sharedBlockMap[i1] = blockId1;
	sharedBlockMap[i2] = blockId2;
}

vec3 sampleFloodfillShared(ivec3 pos, int mask_index, out float weight) {
	int shared_index = getSharedCoord(pos + 1);

	//uint mixMask = 0xFFFF;
	//uint blockId = sharedBlockMap[shared_index];
	weight = 1.0;//blockId == 0u ? 1.0 : 0.0;

//	if (blockId > 0u)
//		ParseBlockLpvData(StaticBlockMap[blockId].lpv_data, mixMask, weight);

	//uint wMask = 1u;//bitfieldExtract(mixMask, mask_index, 1);
	return floodfillBuffer[shared_index];// * wMask;
}

vec3 mixNeighboursDirect(const in ivec3 fragCoord, const in uint mask) {
	uvec3 m1 = uvec3(1u);//(uvec3(mask) >> uvec3(0, 2, 4)) & uvec3(1u);
	uvec3 m2 = uvec3(1u);//(uvec3(mask) >> uvec3(1, 3, 5)) & uvec3(1u);

	vec3 w1, w2;
	vec3 nX1 = sampleFloodfillShared(fragCoord + ivec3(-1,  0,  0), 1, w1.x) * m1.x;
	vec3 nX2 = sampleFloodfillShared(fragCoord + ivec3( 1,  0,  0), 0, w2.x) * m2.x;
	vec3 nY1 = sampleFloodfillShared(fragCoord + ivec3( 0, -1,  0), 3, w1.y) * m1.y;
	vec3 nY2 = sampleFloodfillShared(fragCoord + ivec3( 0,  1,  0), 2, w2.y) * m2.y;
	vec3 nZ1 = sampleFloodfillShared(fragCoord + ivec3( 0,  0, -1), 5, w1.z) * m1.z;
	vec3 nZ2 = sampleFloodfillShared(fragCoord + ivec3( 0,  0,  1), 4, w2.z) * m2.z;

	const float wMaxInv = 1.0 / 6.0;//max(sumOf(w1 + w2), 1.0);
	float avgFalloff = wMaxInv * LpvFalloff;
	return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
}


void main() {
	uvec3 chunkPos = gl_WorkGroupID * gl_WorkGroupSize;
	if (any(greaterThanEqual(chunkPos, VoxelBufferSize))) return;

	ivec3 voxelFrameOffset = GetVoxelFrameOffset();

	populateShared(voxelFrameOffset);
	barrier();

	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	if (any(greaterThanEqual(cellIndex, VoxelBufferSize))) return;

	bool altFrame = ap.time.frames % 2 == 1;

	//ivec3 cellIndexPrev = cellIndex + voxelFrameOffset;

    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 voxelCenter = GetVoxelCenter(ap.camera.pos, viewDir);
    vec3 localPos = cellIndex - voxelCenter + 0.5;

	ivec3 localCellIndex = ivec3(gl_LocalInvocationID);
	uint blockId = sharedBlockMap[getSharedCoord(localCellIndex + 1)];

	bool isFullBlock = false;
	vec3 blockTint = vec3(1.0);
	vec3 lightColor = vec3(0.0);
	int lightRange = 0;
	uint faceMask = 0u;

	if (blockId > 0u) {
		isFullBlock = iris_isFullBlock(blockId);
		uint blockData = iris_getMetadata(blockId);
		faceMask = bitfieldExtract(blockData, 0, 6);

		lightColor = iris_getLightColor(blockId).rgb;
		lightColor = RgbToLinear(lightColor);

		lightRange = iris_getEmission(blockId);

		if (lightRange == 0) {
			blockTint = lightColor;
		}
	}

	vec3 accumLight = vec3(0.0);

	if (!isFullBlock) {
		accumLight = mixNeighboursDirect(localCellIndex, faceMask) * blockTint;
	}

	if (lightRange > 0) {
		vec3 hsv = RgbToHsv(lightColor);
		hsv.z = pow(6.0, (1.0/15.0) * lightRange) - 1.0;
		// hsv.z = lightRange / 15.0;
		accumLight += HsvToRgb(hsv);
	}

	vec3 hsv = RgbToHsv(accumLight);
	hsv.z = log6(hsv.z + 1.0) / LpvBlockRange;
	accumLight = HsvToRgb(hsv);

//	if (lightRange > 0) {
//		vec3 hsv = RgbToHsv(lightColor);
//		hsv.z = (1.0/15.0) * lightRange;
//		// hsv.z = lightRange / 15.0;
//		accumLight += HsvToRgb(hsv);
//	}

	//accumLight = LinearToRgb(accumLight);

	if (altFrame) imageStore(imgFloodFill_alt, cellIndex, vec4(accumLight, 1.0));
	else imageStore(imgFloodFill, cellIndex, vec4(accumLight, 1.0));
}
