#version 430 core

in vec2 lUV;
in vec4 lColor;

layout(location = 0) out vec4 fragColor;


void iris_emitFragment() {
    fragColor = iris_sampleBaseTex(lUV) * lColor;

    if (fragColor.a < 0.1) discard;
}
