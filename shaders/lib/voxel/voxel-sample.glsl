uint SampleVoxelBlock(const in vec3 voxelPos) {
    #ifdef VOXEL_PROVIDED
        ivec3 blockWorldPos = ivec3(floor(GetVoxelLocalPos(voxelPos) + ap.camera.pos + 0.5));
        return uint(iris_getBlockAtPos(blockWorldPos).x);
    #else
        return imageLoad(imgVoxelBlock, ivec3(floor(voxelPos))).r;
    #endif
}
