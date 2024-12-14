#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texBloom;

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
            vec3 sampleColor = textureLod(texColor, sampleCoord, MIP_INDEX).rgb;

            float wX = WEIGHTS[x];
            float wY = WEIGHTS[y];

            finalColor += sampleColor * wX*wY;
        }
    }

    return finalColor;
}

void main() {
    vec3 upColor = BloomUp(texBloom, TEX_SCALE);

    outColor = vec4(upColor, 1.0);
}
