#version 430 core
#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
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
} vOut;

#include "/lib/common.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);

    #if defined VOXEL_ENABLED && defined RENDER_TERRAIN
        // WARN: temp workaround
        mat4 shadowModelViewInverse = inverse(shadowModelView);

        vOut.localPos = mul3(shadowModelViewInverse, shadowViewPos);
        vOut.originPos = vOut.localPos + data.midBlock / 64.0;
    #endif
}

void iris_sendParameters(in VertexData data) {
    vOut.color = data.color;
    vOut.uv = data.uv;

    bool is_trans_fluid = iris_hasFluid(data.blockId);

    if (is_trans_fluid) {
        vOut.color = vec4(1.0);

        // const float lmcoord_y = 1.0;

        // vec3 waveOffset = GetWaveHeight(vOut.localPos + cameraPos, lmcoord_y, timeCounter, WaterWaveOctaveMin);
        // vOut.localOffset.y += waveOffset.y;

        // vOut.localPos += vOut.localOffset;
        // viewPos = mul3(playerModelView, vOut.localPos);
    }

    #ifdef LPV_RSM_ENABLED
        vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
        vOut.localNormal = mat3(playerModelViewInverse) * viewNormal;
    #endif

    vOut.currentCascade = iris_currentCascade;

    #ifdef RENDER_TERRAIN
        vOut.blockId = data.blockId;

        #ifdef VOXEL_ENABLED
            vOut.lmcoord = clamp((data.light - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
        #endif
    #endif
}
