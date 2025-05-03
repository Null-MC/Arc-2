#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec3 outColor;

uniform sampler2D texBloom;

in vec2 uv;

#include "/lib/common.glsl"


vec3 sample_src(const in vec2 uv) {
    return textureLod(texBloom, uv, MIP_INDEX).rgb;
}

void main() {
    ivec2 texSrc_size = textureSize(texBloom, MIP_INDEX);
    vec2 srcPixelSize = 1.0 / texSrc_size;

    vec3 a = sample_src(fma(srcPixelSize, vec2(-1.0, +1.0), uv));
    vec3 b = sample_src(fma(srcPixelSize, vec2( 0.0, +1.0), uv));
    vec3 c = sample_src(fma(srcPixelSize, vec2(+1.0, +1.0), uv));

    vec3 d = sample_src(fma(srcPixelSize, vec2(-1.0,  0.0), uv));
    vec3 e = sample_src(fma(srcPixelSize, vec2( 0.0,  0.0), uv));
    vec3 f = sample_src(fma(srcPixelSize, vec2(+1.0,  0.0), uv));

    vec3 g = sample_src(fma(srcPixelSize, vec2(-1.0, -1.0), uv));
    vec3 h = sample_src(fma(srcPixelSize, vec2( 0.0, -1.0), uv));
    vec3 i = sample_src(fma(srcPixelSize, vec2(+1.0, -1.0), uv));

    outColor = e * 4.0;
    outColor += (b+d+f+h) * 2.0;
    outColor += (a+c+g+i);
    outColor *= 1.0 / 16.0;

    #if BLOOM_INDEX == 0
        outColor *= Scene_EffectBloomStrength;
    #endif
}
