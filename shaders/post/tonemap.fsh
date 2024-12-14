#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;

// in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

#include "/lib/effects/purkinje.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    
    ApplyAutoExposure(color, Scene_AvgExposure);

    color = PurkinjeShift(color, PurkinjeStrength);

    // color = tonemap_jodieReinhard(color);
    color = tonemap_ACESFit2(color);

    outColor = vec4(color, 1.0);
}
