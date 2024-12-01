#version 430 core
#extension GL_AMD_vertex_shader_layer : require

in int blockMask;
in vec3 midBlock;

out vec2 lUV;
out vec4 lColor;


void iris_emitVertex(inout VertexData data) {
    data.clipPos = iris_projectionMatrix * (iris_modelViewMatrix * data.modelPos);
}

void iris_sendParameters(in VertexData data) {
    lUV = data.uv;
    lColor = data.color;
}
