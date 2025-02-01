const int QuadBinGridSize = int(ceil(VOXEL_SIZE / float(QUAD_BIN_SIZE)));


int GetQuadBinIndex(const in ivec3 pos) {
	const ivec3 flatten = ivec3(1, QuadBinGridSize, QuadBinGridSize*QuadBinGridSize);
	return sumOf(pos * flatten);
}
