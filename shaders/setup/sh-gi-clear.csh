#version 430 core

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"
#include "/lib/buffers/sh-gi.glsl"
#include "/lib/lpv/lpv_common.glsl"


void main() {
    ivec3 voxelPos = ivec3(gl_GlobalInvocationID);

    int i = GetLpvIndex(voxelPos);
    SH_LPV_alt[i] = SH_LPV[i] = voxel_empty;
}
