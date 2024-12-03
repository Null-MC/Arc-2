#version 430 core

layout(location = 0) out vec4 outColor;

// in vec2 uv;

#include "/lib/common.glsl"


void iris_emitFragment() {
    vec3 colorFinal = vec3(0.0);

    outColor = vec4(colorFinal, 1.0);
}
