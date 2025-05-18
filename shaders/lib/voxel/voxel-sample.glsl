//#ifdef VOXEL_PROVIDED
//    ivec3 _ap_imod(ivec3 x, ivec3 m) {
//        ivec3 r = ivec3(mod(x, m));
//        return r + m * ivec3(lessThan(r, ivec3(0)));
//    }
//
//    uint _ap_packSectionIndex(ivec3 coords, ivec3 diameter) {
//        coords.y += diameter.z;
//
//        uvec3 flatten = uvec3(1u, diameter.x, diameter.x * diameter.y);
//        uvec3 sum = uvec3(_ap_imod(coords, diameter.xyx)) * flatten;
//        return sum.x + sum.y + sum.z;
//    }
//
//    ivec2 _iris_getBlockAtPos(ivec3 loc) {
//        uint sect = _ap_packSectionIndex(loc >> 4, ap.world.internal_chunkDiameter.xyz);
//
//        uint sectionIndex = ap_voxelIndices[sect];
//        if (sectionIndex == uint(-1)) return ivec2(0, -1);
//
//        return ap_voxelData[sectionIndex].ap_chunkData[iris_getBlockIndex(loc)];
//    }
//#endif

uint SampleVoxelBlock(const in vec3 voxelPos) {
    #ifdef VOXEL_PROVIDED
        // TODO: The +0.5 should not be here! but it breaks without it
        ivec3 blockWorldPos = ivec3(floor(GetVoxelLocalPos(voxelPos + 0.5) + ap.camera.pos));
        //return uint(_iris_getBlockAtPos(blockWorldPos).x);
        return uint(iris_getBlockAtPos(blockWorldPos).x);
    #else
        return imageLoad(imgVoxelBlock, ivec3(floor(voxelPos))).r;
    #endif
}
