#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D TEX_DOWN;
uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"


const float WEIGHTS[3] = float[3](
    0.10558007358450741,
    0.7888398528309852,
    0.10558007358450741);


vec3 BloomUp(in sampler2D texColor, const in float scale) {
    vec2 pixelSize = (1.0 / screenSize) * scale * 2.0;
    vec3 finalColor = vec3(0.0);

    for (int y = 0; y <= 2; y++) {
        for (int x = 0; x <= 2; x++) {
            vec2 sampleOffset = vec2(x, y) - 1.0;
            vec2 sampleCoord = uv + sampleOffset * pixelSize;
            vec3 sampleColor = textureLod(texColor, sampleCoord, 0).rgb;

            float wX = WEIGHTS[x];
            float wY = WEIGHTS[y];

            finalColor += sampleColor * wX*wY;
        }
    }

    return finalColor;
}

void main() {
    vec3 downColor = textureLod(TEX_DOWN, uv, 0).rgb;

    vec3 upColor = BloomUp(TEX_SRC, TEX_SCALE);

    vec3 finalColor = downColor + upColor;

    outColor = vec4(finalColor, 1.0);
}
