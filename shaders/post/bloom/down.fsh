#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"


const float bloomPower = 1.3;
const float bloomStrength = 0.08;

void ScaleInput(inout vec3 color) {
    float lum = luminance(color);
    float lumScaled = lum * bloomStrength;
    float lumCurved = pow(lumScaled, bloomPower);

    float lumFinal = min(lumScaled, lumCurved);

    color *= (lumFinal / max(lum, 0.0001));

    // color = clamp(color, 0.0, 64000.0);
}

void main() {
    vec2 hp = (1.0 / screenSize) * TEX_SCALE;

    vec2 uv1 = uv + vec2(-hp.x, -hp.y);
    vec2 uv2 = uv + vec2( hp.x, -hp.y);
    vec2 uv3 = uv + vec2(-hp.x,  hp.y);
    vec2 uv4 = uv + vec2( hp.x,  hp.y);

    vec3 color1 = textureLod(TEX_SRC, uv1, MIP_INDEX).rgb;
    vec3 color2 = textureLod(TEX_SRC, uv2, MIP_INDEX).rgb;
    vec3 color3 = textureLod(TEX_SRC, uv3, MIP_INDEX).rgb;
    vec3 color4 = textureLod(TEX_SRC, uv4, MIP_INDEX).rgb;

    #if BLOOM_INDEX == 0
        ScaleInput(color1);
        ScaleInput(color2);
        ScaleInput(color3);
        ScaleInput(color4);
    #endif

    vec3 colorFinal = (color1 + color2 + color3 + color4) * 0.25;

    outColor = vec4(colorFinal, 1.0);
}
