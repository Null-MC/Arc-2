#version 430 core
#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
    vec4 color;
    vec2 uv;
    vec3 localNormal;

//    flat int currentCascade;

    #ifdef RENDER_TERRAIN
        flat int currentCascade;
        flat uint blockId;

        #ifdef VOXEL_ENABLED
            vec3 localPos;
            vec2 lmcoord;

            #ifdef RENDER_TERRAIN
                flat vec3 originPos;

                #ifdef VOXEL_BLOCK_FACE
                    flat uint textureId;
                #endif
            #endif
        #endif
    #endif
} vOut;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if defined(RENDER_TERRAIN) && defined(WIND_WAVING_ENABLED)
    #include "/lib/wind_waves.glsl"
#endif

#ifdef VOXEL_ENABLED
    #include "/lib/sampling/lightmap.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
    #if defined(RENDER_TERRAIN) && defined(WIND_WAVING_ENABLED)
        vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
        vec3 localPos = mul3(ap.celestial.viewInv, shadowViewPos);
        ApplyWavingOffset(localPos, data.blockId);
        shadowViewPos = mul3(ap.celestial.view, localPos);
    #else
        vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    #endif

    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);

    #if defined(RENDER_TERRAIN) && defined(VOXEL_ENABLED)
        vOut.localPos = mul3(shadowModelViewInv, shadowViewPos);

        #ifdef RENDER_TERRAIN
            vOut.originPos = vOut.localPos + data.midBlock / 64.0;
        #endif
    #endif

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

    vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
    vOut.localNormal = mat3(shadowModelViewInv) * viewNormal;

//    vOut.currentCascade = iris_currentCascade;

    #ifdef RENDER_TERRAIN
        vOut.currentCascade = iris_currentCascade;
        vOut.blockId = data.blockId;

        #ifdef VOXEL_ENABLED
            vOut.lmcoord = LightMapNorm(data.light);

            #if defined(VOXEL_BLOCK_FACE) && defined(RENDER_TERRAIN)
                vOut.textureId = data.textureId;
            #endif
        #endif
    #endif
}
