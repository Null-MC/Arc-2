#ifdef VOXEL_APERTURE
    uint SampleVoxelBlock(const in vec3 voxelPos) {
        ivec3 blockWorldPos = ivec3(floor(GetVoxelLocalPos(voxelPos) + ap.camera.pos + 0.5));
        return uint(iris_getBlockAtPos(blockWorldPos).x);
    }
#else
    uint SampleVoxelBlock(const in vec3 voxelPos) {
        return imageLoad(imgVoxelBlock, ivec3(floor(voxelPos))).r;
    }
#endif
