const int LightBinGridSize = int(ceil(VOXEL_SIZE / float(LIGHT_BIN_SIZE)));


int GetLightBinIndex(const in ivec3 pos) {
	const ivec3 flatten = ivec3(1, LightBinGridSize, LightBinGridSize*LightBinGridSize);
	return sumOf(pos * flatten);
}

uint GetVoxelIndex(const in ivec3 voxelPos) {
	const ivec3 flatten = ivec3(1, VOXEL_SIZE, VOXEL_SIZE*VOXEL_SIZE);
	return uint(sumOf(voxelPos * flatten));
}

ivec3 GetVoxelPos(const in uint voxelIndex) {
	ivec3 pos;
	pos.z = int(floor(voxelIndex / float(VOXEL_SIZE*VOXEL_SIZE)));
	pos.y = int(floor((voxelIndex - pos.z*VOXEL_SIZE*VOXEL_SIZE) / float(VOXEL_SIZE)));
	pos.x = int(voxelIndex % VOXEL_SIZE);
	return pos;
}
