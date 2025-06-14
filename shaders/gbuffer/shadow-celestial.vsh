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

            //#ifdef RENDER_TERRAIN
                flat vec3 originPos;

                #ifdef VOXEL_BLOCK_FACE
                    flat uint textureId;
                #endif
            //#endif
        #endif
    #endif
} vOut;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if defined(RENDER_TERRAIN) && defined(SKY_WIND_ENABLED)
    #include "/lib/noise/hash.glsl"
    #include "/lib/wind_waves.glsl"
#endif

#ifdef VOXEL_ENABLED
    #include "/lib/sampling/lightmap.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);

    #ifdef RENDER_TERRAIN
        vec3 localPos = mul3(ap.celestial.viewInv, shadowViewPos);
        vec3 originPos = localPos + data.midBlock / 64.0;

        #ifdef SKY_WIND_ENABLED
            ApplyWavingOffset(localPos, originPos, data.blockId);
            shadowViewPos = mul3(ap.celestial.view, localPos);
        #endif

        vOut.localPos = localPos;

        #ifdef VOXEL_ENABLED
            vOut.originPos = originPos;
        #endif
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

    vec3 shadowViewNormal = mat3(iris_modelViewMatrix) * data.normal;
    vOut.localNormal = mat3(ap.celestial.viewInv) * shadowViewNormal;

//    vOut.currentCascade = iris_currentCascade;

    #ifdef RENDER_TERRAIN
        vOut.currentCascade = iris_currentCascade;
        vOut.blockId = data.blockId;

        #ifdef VOXEL_ENABLED
            vOut.lmcoord = LightMapNorm(data.light);

            #ifdef VOXEL_BLOCK_FACE
                vOut.textureId = data.textureId;
            #endif
        #endif
    #endif
}
