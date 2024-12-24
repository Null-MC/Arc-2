#version 430 core
#extension GL_NV_gpu_shader5: enable
#extension GL_AMD_vertex_shader_layer : require

layout(triangles) in;
layout(triangle_strip, max_vertices=3) out;

in VertexData2 {
    vec4 color;
    vec2 uv;
    flat int currentCascade;

    #ifdef LPV_RSM_ENABLED
        vec3 localNormal;
    #endif

    #if (defined LPV_ENABLED || defined RT_ENABLED) && defined RENDER_TERRAIN
        vec3 localPos;
        flat vec3 originPos;
        flat uint blockId;
    #endif
} vIn[];

out VertexData2 {
    vec4 color;
    vec2 uv;

    #ifdef LPV_RSM_ENABLED
        vec3 localNormal;
    #endif
} vOut;

#if defined LPV_ENABLED || defined RT_ENABLED
    layout(r32ui) uniform writeonly uimage3D imgVoxelBlock;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"

#if defined RT_ENABLED && defined RENDER_TERRAIN
    // #include "/lib/buffers/light-list.glsl"
    #include "/lib/buffers/triangle-list.glsl"
#endif

#if defined RT_ENABLED || defined LPV_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
#endif

#if defined RT_ENABLED && defined RENDER_TERRAIN
    // #include "/lib/voxel/light-list.glsl"
    #include "/lib/voxel/triangle-list.glsl"
#endif


void main() {
    for (int v = 0; v < 3; v++) {
        vOut.color = vIn[v].color;
        vOut.uv = vIn[v].uv;

        #if defined LPV_ENABLED && defined LPV_RSM_ENABLED
            vOut.localNormal = vIn[v].localNormal;
        #endif

        gl_Position = gl_in[v].gl_Position;
        gl_Layer = vIn[v].currentCascade;

        EmitVertex();
    }

    EndPrimitive();


    #if (defined LPV_ENABLED || defined RT_ENABLED) && defined RENDER_TERRAIN
        vec3 voxelPos = GetVoxelPosition(vIn[0].originPos);

        if (IsInVoxelBounds(voxelPos)) {
            imageStore(imgVoxelBlock, ivec3(voxelPos), uvec4(vIn[0].blockId));

            #if defined RT_ENABLED && defined RT_TRI_ENABLED
                bool isFullBlock = iris_isFullBlock(vIn[0].blockId);

                if (!isFullBlock && vIn[0].currentCascade == 0) {
                    ivec3 triangleBinPos = ivec3(floor(voxelPos / TRIANGLE_BIN_SIZE));
                    int triangleBinIndex = GetTriangleBinIndex(triangleBinPos);

                    uint triangleIndex = atomicAdd(TriangleBinMap[triangleBinIndex].triangleCount, 1u);

                    if (triangleIndex < TRIANGLE_BIN_MAX) {
                        vec3 originBase = vIn[0].originPos - 0.5;
                        vec3 offset = voxelPos - 0.5 - triangleBinPos*TRIANGLE_BIN_SIZE;

                        Triangle tri;
                        tri.pos[0] = f16vec3(vIn[0].localPos - originBase + offset);
                        tri.pos[1] = f16vec3(vIn[1].localPos - originBase + offset);
                        tri.pos[2] = f16vec3(vIn[2].localPos - originBase + offset);

                        TriangleBinMap[triangleBinIndex].triangleList[triangleIndex] = tri;

                        atomicAdd(Scene_TriangleCount, 1u);
                    }


                    // vec2 uv_min = min(vIn[0].uv, vIn[1].uv);
                    // uv_min = min(uv_min, vIn[2].uv);

                    // vec2 uv_max = max(vIn[0].uv, vIn[1].uv);
                    // uv_max = max(uv_max, vIn[2].uv);

                    // float len_01 = lengthSq(vIn[0].localPos - vIn[1].localPos);
                    // float len_12 = lengthSq(vIn[1].localPos - vIn[2].localPos);
                    // float len_20 = lengthSq(vIn[2].localPos - vIn[0].localPos);

                    // vec3 center;
                    // if (len_01 > max(len_12, len_20)) center = vIn[0].localPos + vIn[1].localPos;
                    // else if (len_12 > len_20) center = vIn[1].localPos + vIn[2].localPos;
                    // else center = vIn[2].localPos + vIn[0].localPos;
                    // center *= 0.5;

                    // TODO: store quads
                    // vec3 center
                    // vec3 normal
                    // float width
                    // float height
                    // vec2 uv-min
                    // vec2 uv-max
                }
            #endif
        }
    #endif
}
