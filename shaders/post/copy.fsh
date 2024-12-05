#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"


void main() {
    outColor = textureLod(TEX_SRC, uv, 0);
}
