#version 430 core

// out vec2 uv;


void iris_emitVertex(inout VertexData data) {
    // data.pos = iris_projectionMatrix * iris_modelViewMatrix * data.pos;
    data.pos = vec4(-10.0);
}

void iris_sendParameters(in VertexData data) {
    // uv = data.uv;
}
