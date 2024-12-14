#version 430 core

layout(location = 0) out vec4 outColor;

// in vec2 uv;


void iris_emitFragment() {
    outColor = vec4(vec3(0.0), 1.0);
}
