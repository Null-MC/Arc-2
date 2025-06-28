#version 430 core
#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"


#if defined(RENDER_TERRAIN) && !defined(VOXEL_PROVIDED)
    #define IS_TERRAIN_VOXEL
#endif

#if defined(RENDER_TERRAIN) && defined(VOXEL_BLOCK_FACE)
    #define IS_TERRAIN_BLOCKFACE
#endif

#if (defined(RENDER_TERRAIN) || defined(RENDER_ENTITY)) && defined(VOXEL_TRI_ENABLED)
    #define IS_TERRAIN_ENTITY_QUADS
#endif


out VertexData2 {
    vec4 color;
    vec2 uv;

    #ifdef RENDER_TERRAIN
        flat uint blockId;
    #endif

    #ifdef IS_TERRAIN_BLOCKFACE
        vec3 localNormal;
    #endif

    #if defined(IS_TERRAIN_BLOCKFACE) || defined(IS_TERRAIN_ENTITY_QUADS)
        flat uint textureId;
        vec2 lmcoord;
    #endif

    #if defined(IS_TERRAIN_VOXEL) || defined(IS_TERRAIN_BLOCKFACE) || defined(IS_TERRAIN_ENTITY_QUADS)
        flat int currentCascade;

        #ifdef RENDER_TERRAIN
            flat vec3 originPos;
        #endif
    #endif

    #ifdef IS_TERRAIN_ENTITY_QUADS
        vec3 localPos;
    #endif
} vOut;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if defined(RENDER_TERRAIN) && defined(SKY_WIND_ENABLED)
    #include "/lib/noise/hash.glsl"
    #include "/lib/wind_waves.glsl"
#endif

#include "/lib/sampling/lightmap.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);

    #if defined(RENDER_TERRAIN) || defined(IS_TERRAIN_ENTITY_QUADS)
        vec3 localPos = mul3(ap.celestial.viewInv, shadowViewPos);
    #endif

    #ifdef RENDER_TERRAIN
        vec3 midPos = data.midBlock / 64.0;
        vec3 originPos = localPos + midPos;

        #ifdef SKY_WIND_ENABLED
            localPos += GetWavingOffset(originPos, midPos, data.blockId);
            shadowViewPos = mul3(ap.celestial.view, localPos);
        #endif

        #if defined(IS_TERRAIN_BLOCKFACE) || defined(IS_TERRAIN_ENTITY_QUADS)
            vOut.originPos = originPos;
        #endif
    #endif

    #if defined(IS_TERRAIN_ENTITY_QUADS)
        vOut.localPos = localPos;
    #endif

    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);

    if (iris_hasTag(data.blockId, TAG_CARPET)) data.clipPos = vec4(-10.0);

    // TODO: needs layer check
    //if (iris_hasTag(data.blockId, TAG_SNOW)) data.clipPos = vec4(-10.0);
}

void iris_sendParameters(in VertexData data) {
    vOut.color = data.color;
    vOut.uv = data.uv;

    bool is_trans_fluid = iris_hasFluid(data.blockId);

    if (is_trans_fluid) {
        vOut.color = vec4(1.0);

        // const float lmcoord_y = 1.0;

        // vec3 waveOffset = GetWaveHeight(vOut.localPos + ap.camera.pos, lmcoord_y, ap.time.elapsed, WaterWaveOctaveMin);
        // vOut.localOffset.y += waveOffset.y;

        // vOut.localPos += vOut.localOffset;
        // viewPos = mul3(ap.camera.view, vOut.localPos);
    }

    #ifdef RENDER_TERRAIN
        vOut.blockId = data.blockId;
    #endif

    #ifdef IS_TERRAIN_BLOCKFACE
        vec3 shadowViewNormal = mat3(iris_modelViewMatrix) * data.normal;
        vOut.localNormal = mat3(ap.celestial.viewInv) * shadowViewNormal;
    #endif

    #if defined(IS_TERRAIN_VOXEL) || defined(IS_TERRAIN_BLOCKFACE) || defined(IS_TERRAIN_ENTITY_QUADS)
        vOut.currentCascade = iris_currentCascade;
    #endif

    #if defined(IS_TERRAIN_BLOCKFACE) || defined(IS_TERRAIN_ENTITY_QUADS)
        vOut.textureId = data.textureId;
        vOut.lmcoord = LightMapNorm(data.light);
    #endif
}
