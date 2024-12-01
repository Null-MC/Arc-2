#version 430 core

out vec2 uv;


void iris_emitVertex(inout VertexData data) {
    data.clipPos = iris_projectionMatrix * iris_modelViewMatrix * data.modelPos;
}

void iris_sendParameters(in VertexData data) {
    uv = data.uv;
}
