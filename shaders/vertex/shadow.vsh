#version 430 core
#extension GL_AMD_vertex_shader_layer : require

layout(location = 6) in int blockMask;

// in int blockMask;
// in vec3 midBlock;

out vec2 lUV;
out vec4 lColor;

#ifdef LPV_ENABLED
    layout(r8ui) uniform writeonly uimage3D imgVoxelBlock;
#endif

#include "/lib/common.glsl"
#include "/lib/voxel/voxel_common.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);

    // #ifdef LPV_ENABLED
    //     // WARN: temp workaround
    //     mat4 shadowModelViewInverse = inverse(shadowModelView);

    //     vec3 localPos = mul3(shadowModelViewInverse, shadowViewPos);
    //     localPos += midBlock / 64.0;

    //     vec3 voxelPos = GetVoxelPosition(localPos);

    //     if (IsInVoxelBounds(voxelPos)) {
    //         uint blockId = 1u;

    //         bool isEmissive = bitfieldExtract(blockMask, 3, 1) != 0;
    //         if (isEmissive) blockId = 2u;

    //         imageStore(imgVoxelBlock, ivec3(voxelPos), uvec4(blockId));
    //     }
    // #endif
}

void iris_sendParameters(in VertexData data) {
    lUV = data.uv;
    lColor = data.color;

    #ifdef LPV_ENABLED
        // WARN: temp workaround
        mat4 shadowModelViewInverse = inverse(shadowModelView);

        vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
        vec3 localPos = mul3(shadowModelViewInverse, shadowViewPos);
        localPos += data.midBlock / 64.0;

        vec3 voxelPos = GetVoxelPosition(localPos);

        if (IsInVoxelBounds(voxelPos)) {
            bool isFullBlock = bitfieldExtract(blockMask, 0, 1) != 0;
            bool isEmissive = bitfieldExtract(blockMask, 3, 1) != 0;

            uint blockId = isFullBlock ? 1u : 0u;
            if (isEmissive) blockId = 2u;

            imageStore(imgVoxelBlock, ivec3(voxelPos), uvec4(blockId));
        }
    #endif
}
