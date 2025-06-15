#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "/lib/common.glsl"
#include "/lib/buffers/light-list.glsl"

#include "/lib/voxel/light-list.glsl"


void main() {
    ivec3 binPos = ivec3(gl_GlobalInvocationID);

    if (all(lessThan(gl_GlobalInvocationID, uvec3(LightBinGridSize)))) {
        int binIndex = GetLightBinIndex(binPos);

        LightBinMap[binIndex].lightCount = 0u;

        #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
            LightBinMap[binIndex].shadowLightCount = 0u;
        #endif
    }
}
