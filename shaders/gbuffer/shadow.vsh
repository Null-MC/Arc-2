#version 430 core
#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
    vec4 color;
    vec2 uv;
    vec3 localNormal;
    flat int currentCascade;

    #ifdef RENDER_TERRAIN
        flat uint blockId;
    #endif

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
} vOut;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);

    #ifdef VOXEL_ENABLED
        vOut.localPos = mul3(shadowModelViewInv, shadowViewPos);

        #ifdef RENDER_TERRAIN
            vOut.originPos = vOut.localPos + data.midBlock / 64.0;
        #endif
    #endif
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

    vOut.currentCascade = iris_currentCascade;

    #ifdef RENDER_TERRAIN
        vOut.blockId = data.blockId;
    #endif

    #ifdef VOXEL_ENABLED
        vOut.lmcoord = clamp((data.light - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

        #if defined(VOXEL_BLOCK_FACE) && defined(RENDER_TERRAIN)
            vOut.textureId = data.textureId;
        #endif
    #endif
}
