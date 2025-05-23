#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"
#include "/lib/buffers/wsgi.glsl"

#include "/lib/voxel/wsgi-common.glsl"


void main() {
    for (int cascade = 0; cascade < WSGI_CASCADE_COUNT; cascade++) {
        ivec3 voxelPos = ivec3(gl_GlobalInvocationID);
        int wsgi_i = wsgi_getBufferIndex(voxelPos, cascade);

        SH_LPV_alt[wsgi_i] = voxel_empty;
        SH_LPV[wsgi_i] = voxel_empty;
    }
}
