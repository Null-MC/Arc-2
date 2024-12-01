#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
// uniform sampler2D texBloom_6;

in vec2 uv;

#include "/lib/common.glsl"


void main() {
    vec3 color = textureLod(texFinal, uv, 0).rgb;

    // #ifdef ENABLE_BLOOM
    //     color = textureLod(texBloom_32, uv, 0).rgb;
    // #endif
    
    // vec2 previewCoord = (uv - 0.02) / 0.3;
    // if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
    //     color = textureLod(texBloom_6, previewCoord, 0).rgb;
    // }

    color = LinearToRgb(color);

    outColor = vec4(color, 1.0);
}
