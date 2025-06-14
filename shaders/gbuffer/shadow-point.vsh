#version 430 core
//#extension GL_ARB_shader_viewport_layer_array: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
    vec2 uv;
} vOut;

#include "/lib/common.glsl"
//#include "/lib/buffers/scene.glsl"


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;
}
