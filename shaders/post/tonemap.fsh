#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
uniform sampler2D texExposure;

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
#endif

in vec2 uv;

// #include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/exposure.glsl"


vec3 tonemap_jodieReinhard(vec3 c) {
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

vec3 tonemap_ACESFit2(const in vec3 color) {
    const mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777);

    const mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602);

    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return clamp(m2 * (a / b), 0.0, 1.0);
}


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    
    ApplyAutoExposure(color, texExposure);

    // color = tonemap_jodieReinhard(color);
    color = tonemap_ACESFit2(color);

    #ifdef DEBUG_HISTOGRAM
        vec2 previewCoord = (uv - 0.01) / vec2(0.2, 0.1);
        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
            uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
            color = vec3(step(previewCoord.y*previewCoord.y, sampleVal / (screenSize.x*screenSize.y)));
        }
    #endif

    outColor = vec4(color, 1.0);
}
