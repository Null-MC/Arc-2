#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec3 outColor;

uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"


vec3 sample_src(const in vec2 uv) {
    return textureLod(TEX_SRC, uv, MIP_INDEX).rgb;
}

void main() {
    ivec2 texSrc_size = textureSize(TEX_SRC, MIP_INDEX);
    vec2 srcPixelSize = 1.0 / texSrc_size;

    vec3 a = sample_src(fma(srcPixelSize, vec2(-2.0, +2.0), uv));
    vec3 b = sample_src(fma(srcPixelSize, vec2( 0.0, +2.0), uv));
    vec3 c = sample_src(fma(srcPixelSize, vec2(+2.0, +2.0), uv));

    vec3 d = sample_src(fma(srcPixelSize, vec2(-2.0, 0.0), uv));
    vec3 e = sample_src(fma(srcPixelSize, vec2( 0.0, 0.0), uv));
    vec3 f = sample_src(fma(srcPixelSize, vec2(+2.0, 0.0), uv));

    vec3 g = sample_src(fma(srcPixelSize, vec2(-2.0, -2.0), uv));
    vec3 h = sample_src(fma(srcPixelSize, vec2( 0.0, -2.0), uv));
    vec3 i = sample_src(fma(srcPixelSize, vec2(+2.0, -2.0), uv));

    vec3 j = sample_src(fma(srcPixelSize, vec2(-1.0, +1.0), uv));
    vec3 k = sample_src(fma(srcPixelSize, vec2(+1.0, +1.0), uv));
    vec3 l = sample_src(fma(srcPixelSize, vec2(-1.0, -1.0), uv));
    vec3 m = sample_src(fma(srcPixelSize, vec2(+1.0, -1.0), uv));

    outColor  = e * 0.125;
    outColor += (a+c+g+i) * 0.03125;
    outColor += (b+d+f+h) * 0.0625;
    outColor += (j+k+l+m) * 0.125;
}
