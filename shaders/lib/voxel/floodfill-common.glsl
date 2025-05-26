bool floodfill_isInBounds(const in ivec3 voxelPos) {
    return clamp(voxelPos, 0, VOXEL_SIZE-1) == voxelPos;
}

bool floodfill_isInBounds(const in vec3 voxelPos) {
    return clamp(voxelPos, 0.5, VOXEL_SIZE-0.5) == voxelPos;
}
