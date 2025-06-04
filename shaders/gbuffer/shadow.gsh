#version 430 core
#extension GL_ARB_shader_viewport_layer_array : require

#include "/settings.glsl"
#include "/lib/constants.glsl"

#define VOXEL_WRITE

layout(triangles) in;
layout(triangle_strip, max_vertices=3) out;

in VertexData2 {
    vec4 color;
    vec2 uv;
    vec3 localNormal;

    #ifdef RENDER_TERRAIN
        flat int currentCascade;
        flat uint blockId;

        #ifdef VOXEL_ENABLED
            vec3 localPos;
            vec2 lmcoord;

            //#ifdef RENDER_TERRAIN
                flat vec3 originPos;

                #ifdef VOXEL_BLOCK_FACE
                    flat uint textureId;
                #endif
            //#endif
        #endif
    #endif
} vIn[];

out VertexData2 {
    vec4 color;
    vec2 uv;
    vec3 localNormal;

    #ifdef RENDER_TERRAIN
        flat uint blockId;
    #endif
} vOut;

#include "/lib/common.glsl"

#ifdef VOXEL_ENABLED
    #ifdef RENDER_TERRAIN
        #include "/lib/buffers/voxel-block.glsl"
    #endif

    #ifdef VOXEL_TRI_ENABLED
        #include "/lib/buffers/quad-list.glsl"
    #endif

    #include "/lib/voxel/voxel-common.glsl"

    #ifdef VOXEL_TRI_ENABLED
        #include "/lib/voxel/quad-list.glsl"
    #endif
#endif


void main() {
    for (int v = 0; v < 3; v++) {
        vOut.color = vIn[v].color;
        vOut.uv = vIn[v].uv;

        vOut.localNormal = vIn[v].localNormal;

        #ifdef RENDER_TERRAIN
            vOut.blockId = vIn[v].blockId;
        #endif

        gl_Position = gl_in[v].gl_Position;
        gl_Layer = vIn[v].currentCascade;

        EmitVertex();
    }

    EndPrimitive();

    #ifdef VOXEL_ENABLED
        if (gl_PrimitiveIDIn % 2 == 0) {
            #ifdef RENDER_TERRAIN
                vec3 voxelPos = voxel_GetBufferPosition(vIn[0].originPos);
            #else
                vec3 originPos = (vIn[0].localPos + vIn[1].localPos + vIn[2].localPos) / 3.0;
                vec3 voxelPos = voxel_GetBufferPosition(originPos);
            #endif

            if (voxel_isInBounds(voxelPos)) {
                #ifdef RENDER_TERRAIN
                    #ifndef VOXEL_PROVIDED
                        imageStore(imgVoxelBlock, ivec3(voxelPos), uvec4(vIn[0].blockId));
                    #endif

                    #ifdef VOXEL_BLOCK_FACE
                        // TODO: average face properties?

                        if (vIn[0].blockId > 0u && vIn[0].currentCascade == VOXEL_SHADOW_CASCADE) {
                            bool doVoxelize = iris_isFullBlock(vIn[0].blockId);

                            uint blockMapId = iris_getCustomId(vIn[0].blockId);
                            if (blockMapId == BLOCK_GRASS && abs(vIn[0].localNormal.y) < 0.5 && any(lessThan(vIn[0].color.rgb, vec3(1.0))))
                                doVoxelize = false;

                            bool isCarpetTop = false;
                            if (vIn[0].localNormal.y > 0.98) {
                                isCarpetTop = iris_hasTag(vIn[0].blockId, TAG_CARPET);

                                // TODO: needs layer check
//                                if (iris_hasTag(vIn[0].blockId, TAG_SNOW))
//                                    isCarpetTop = true;

                                if (isCarpetTop) doVoxelize = true;
                            }

                            uint blockTags = iris_blockInfo.blocks[vIn[0].blockId].z;
                            const uint make_solid_tags = (1u << TAG_LEAVES) | (1u << TAG_STAIRS) | (1u << TAG_SLABS);
                            if (iris_hasAnyTag(blockTags, make_solid_tags)) doVoxelize = true;

                            if (doVoxelize) {
                                ivec3 blockPos = ivec3(voxelPos);

                                VoxelBlockFace blockFace;
                                blockFace.tex_id = vIn[0].textureId;
                                blockFace.data = 0u;

                                // TODO: if snow layer/carpet, write to voxel below
                                if (isCarpetTop) blockPos.y--;

                                SetBlockFaceTint(blockFace.data, vIn[0].color.rgb);
                                SetBlockFaceLightMap(blockFace.data, vIn[0].lmcoord);

                                int blockFaceIndex = GetVoxelBlockFaceIndex(vIn[0].localNormal);
                                int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(blockPos, blockFaceIndex);
                                VoxelBlockFaceMap[blockFaceMapIndex] = blockFace;
                            }
                        }
                    #endif
                #endif

                #if defined(VOXEL_TRI_ENABLED) && (defined(RENDER_TERRAIN) || defined(RENDER_ENTITY))
                    #ifdef RENDER_TERRAIN
                        bool isFluid = iris_hasFluid(vIn[0].blockId);
                    #else
                        const bool isFluid = false;
                    #endif

                    if (vIn[0].currentCascade == VOXEL_SHADOW_CASCADE && !isFluid) {
                        ivec3 quadBinPos = ivec3(floor(voxelPos / QUAD_BIN_SIZE));
                        int quadBinIndex = GetQuadBinIndex(quadBinPos);

                        uint quadIndex = atomicAdd(SceneQuads.bin[quadBinIndex].count, 1u);

                        if (quadIndex < QUAD_BIN_MAX) {
                            //vec3 offset = ivec3(voxelPos) - quadBinPos*QUAD_BIN_SIZE;
                            //vec3 originBase = vIn[0].originPos - 0.5 - offset;

                            vec3 originBase = voxel_getLocalPosition(quadBinPos*QUAD_BIN_SIZE);
                            Quad quad;

                            // Reorder Vertices!
                            quad.pos[2] = SetQuadVertexPos(vIn[0].localPos - originBase);
                            quad.pos[0] = SetQuadVertexPos(vIn[1].localPos - originBase);
                            quad.pos[1] = SetQuadVertexPos(vIn[2].localPos - originBase);

                            #ifdef RENDER_TERRAIN
                                quad.tint = packUnorm4x8(vIn[0].color);

                                vec2 uv_min = min(min(vIn[0].uv, vIn[1].uv), vIn[2].uv);
                                quad.uv_min = SetQuadUV(uv_min);

                                vec2 uv_max = max(max(vIn[0].uv, vIn[1].uv), vIn[2].uv);
                                quad.uv_max = SetQuadUV(uv_max);
                            #else
                                vec2 midUV = 0.5 * (vIn[1].uv + vIn[2].uv);
                                vec4 avgColor = iris_sampleBaseTexLod(midUV, 4);
                                //                                vec3 avgColor = textureLod(irisInt_BaseTex, midUV, 4).rgb;

                                if (avgColor.a < 0.8) return;

                                quad.tint = packUnorm4x8(vec4(avgColor.rgb, 1.0));

                                quad.uv_min = 0u;//packUnorm4x8(vec4(avgColor, 1.0));
                                quad.uv_max = 0u;
                            #endif

                            vec2 vIn3_lmcoord = vec2(0.0); // TODO: idk!
                            SetQuadLightMapCoord(quad.lmcoord, vIn[0].lmcoord, vIn[1].lmcoord, vIn[2].lmcoord, vIn3_lmcoord);

                            SceneQuads.bin[quadBinIndex].quadList[quadIndex] = quad;

                            #ifdef DEBUG_QUADS
                                atomicAdd(SceneQuads.total, 1u);
                            #endif
                        }
                    }
                #endif
            }
        }
    #endif
}
