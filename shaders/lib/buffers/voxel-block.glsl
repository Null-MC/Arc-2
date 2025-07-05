#ifdef VOXEL_WRITE
    layout(r32ui) uniform writeonly uimage3D imgVoxelBlock;
#else
    layout(r32ui) uniform readonly uimage3D imgVoxelBlock;
#endif
