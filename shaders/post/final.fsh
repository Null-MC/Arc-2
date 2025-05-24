#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

// in vec2 uv;

uniform sampler2D TEX_SRC;

#include "/lib/common.glsl"
#include "/lib/bayer.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(TEX_SRC, iuv, 0).rgb;
    
    color = LinearToRgb(color);

    float dither = GetBayerValue(ivec2(gl_FragCoord.xy));
    color += (dither - 0.5) * (1.0/255.0);

    outColor = vec4(color, 1.0);
}
