#version 430 core
#extension GL_AMD_vertex_shader_layer : require

layout(location = 6) in int blockMask;

out VertexData2 {
    vec4 color;
    vec2 uv;

    #if defined LPV_ENABLED && defined LPV_RSM_ENABLED
        vec3 localNormal;
    #endif
} vOut;

#ifdef LPV_ENABLED
    layout(r8ui) uniform writeonly uimage3D imgVoxelBlock;
#endif

#include "/lib/common.glsl"
#include "/lib/voxel/voxel_common.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);
}

void iris_sendParameters(in VertexData data) {
    vOut.color = data.color;
    vOut.uv = data.uv;

    bool isWater = bitfieldExtract(blockMask, 6, 1) != 0;

    if (isWater) {
        vOut.color = vec4(1.0);

        // const float lmcoord_y = 1.0;

        // vec3 waveOffset = GetWaveHeight(vOut.localPos + cameraPos, lmcoord_y, timeCounter, WaterWaveOctaveMin);
        // vOut.localOffset.y += waveOffset.y;

        // vOut.localPos += vOut.localOffset;
        // viewPos = mul3(playerModelView, vOut.localPos);
    }

    #ifdef LPV_ENABLED
        #ifdef LPV_RSM_ENABLED
            vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
            vOut.localNormal = mat3(playerModelViewInverse) * viewNormal;
        #endif

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
