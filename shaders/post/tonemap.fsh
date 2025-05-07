#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;

// in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

//#include "/lib/effects/purkinje.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    
    ApplyAutoExposure(color, clamp(Scene_AvgExposure, -100.0, 100.0));

    //color = PurkinjeShift(color, PurkinjeStrength);

    //color = tonemap_jodieReinhard(color);
    //color = tonemap_Lottes(color);
    color = tonemap_ACESFit2(color);
    //color = tonemap_AgX(color);
    //color = tonemap_Commerce(color);

    //color = color / (color + 0.155) * 1.019;

    outColor = vec4(color, 1.0);
}
