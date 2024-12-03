#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
// uniform usampler2D texHistogram;

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/bayer.glsl"


void main() {
    vec3 color = textureLod(texFinal, uv, 0).rgb;

    // #ifdef ENABLE_BLOOM
    //     color = textureLod(texBloom_32, uv, 0).rgb;
    // #endif
    
    // vec2 previewCoord = (uv - 0.02) / 0.3;
    // if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
    //     uint sampleVal = textureLod(texHistogram, previewCoord, 0).r;
    //     color = vec3(1.0 / (sampleVal+1.0));
    // }

    color = LinearToRgb(color);

    float dither = GetBayerValue(ivec2(gl_FragCoord.xy));
    color += (dither - 0.5) * (1.0/255.0);

    outColor = vec4(color, 1.0);
}
