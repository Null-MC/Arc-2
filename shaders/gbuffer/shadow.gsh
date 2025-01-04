#version 430 core
#extension GL_NV_gpu_shader5: enable
#extension GL_ARB_shader_viewport_layer_array : require

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(triangles) in;
layout(triangle_strip, max_vertices=3) out;

in VertexData2 {
    vec4 color;
    vec2 uv;
    flat int currentCascade;

    #ifdef LPV_RSM_ENABLED
        vec3 localNormal;
    #endif

    #ifdef RENDER_TERRAIN
        flat uint blockId;

        #ifdef VOXEL_ENABLED
            vec3 localPos;
            vec2 lmcoord;
            flat vec3 originPos;
        #endif
    #endif
} vIn[];

out VertexData2 {
    vec4 color;
    vec2 uv;

    #ifdef LPV_RSM_ENABLED
        vec3 localNormal;
    #endif

    #ifdef RENDER_TERRAIN
        flat uint blockId;
    #endif
} vOut;

#if defined(VOXEL_ENABLED) && defined(RENDER_TERRAIN)
    layout(r32ui) uniform writeonly uimage3D imgVoxelBlock;
#endif

#include "/lib/common.glsl"

#if defined(VOXEL_ENABLED) && defined(RENDER_TERRAIN)
    #ifdef VOXEL_TRI_ENABLED
        #include "/lib/buffers/triangle-list.glsl"
    #endif

    #include "/lib/voxel/voxel_common.glsl"

    #ifdef VOXEL_TRI_ENABLED
        #include "/lib/voxel/triangle-list.glsl"
    #endif
#endif


void main() {
    for (int v = 0; v < 3; v++) {
        vOut.color = vIn[v].color;
        vOut.uv = vIn[v].uv;

        #if defined(LPV_ENABLED) && defined(LPV_RSM_ENABLED)
            vOut.localNormal = vIn[v].localNormal;
        #endif

        #ifdef RENDER_TERRAIN
            vOut.blockId = vIn[v].blockId;
        #endif

        gl_Position = gl_in[v].gl_Position;
        gl_Layer = vIn[v].currentCascade;

        EmitVertex();
    }

    EndPrimitive();


    #if defined(VOXEL_ENABLED) && defined(RENDER_TERRAIN)
        vec3 voxelPos = GetVoxelPosition(vIn[0].originPos);

        if (IsInVoxelBounds(voxelPos)) {
            imageStore(imgVoxelBlock, ivec3(voxelPos), uvec4(vIn[0].blockId));

            #ifdef VOXEL_TRI_ENABLED
                bool isFluid = iris_hasFluid(vIn[0].blockId);

                if (vIn[0].currentCascade == 0 && !isFluid) {
                    ivec3 triangleBinPos = ivec3(floor(voxelPos / TRIANGLE_BIN_SIZE));
                    int triangleBinIndex = GetTriangleBinIndex(triangleBinPos);

                    uint triangleIndex = atomicAdd(TriangleBinMap[triangleBinIndex].triangleCount, 1u);

                    if (triangleIndex < TRIANGLE_BIN_MAX) {
                        vec3 originBase = vIn[0].originPos - 0.5;
                        vec3 offset = ivec3(voxelPos) - triangleBinPos*TRIANGLE_BIN_SIZE;

                        Triangle tri;
                        tri.tint = packUnorm4x8(vIn[0].color);

                        tri.pos[0] = SetTriangleVertexPos(vIn[0].localPos - originBase + offset);
                        tri.pos[1] = SetTriangleVertexPos(vIn[1].localPos - originBase + offset);
                        tri.pos[2] = SetTriangleVertexPos(vIn[2].localPos - originBase + offset);

                        tri.uv[0] = f16vec2(vIn[0].uv);
                        tri.uv[1] = f16vec2(vIn[1].uv);
                        tri.uv[2] = f16vec2(vIn[2].uv);

                        tri.lmcoord = SetTriangleLightMapCoord(vIn[0].lmcoord, vIn[1].lmcoord, vIn[2].lmcoord);

                        TriangleBinMap[triangleBinIndex].triangleList[triangleIndex] = tri;

                        atomicAdd(Scene_TriangleCount, 1u);
                    }
                }
            #endif
        }
    #endif
}
