#version 430 core
//#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;
} vOut;

#include "/lib/common.glsl"
//#include "/lib/buffers/scene.glsl"

#ifdef SKY_WIND_ENABLED
    #include "/lib/noise/hash.glsl"
    #include "/lib/wind_waves.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);

    vOut.modelPos = data.modelPos.xyz;

    #ifdef SKY_WIND_ENABLED
        //vec3 modelPos = data.modelPos.xyz;
        vec3 localPos = vOut.modelPos + ap.point.pos[iris_currentPointLight].xyz;

        vec3 midPos = data.midBlock / 64.0;
        vec3 originPos = localPos + midPos;
        vec3 wavingOffset = GetWavingOffset(originPos, midPos, data.blockId);

        vOut.modelPos += wavingOffset;
        shadowViewPos = mul3(iris_modelViewMatrix, vOut.modelPos);
    #endif

    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;

    uint blockId = ap.point.block[iris_currentPointLight];
    vOut.isFull = iris_isFullBlock(blockId);
}
