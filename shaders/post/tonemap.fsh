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
    vec3 color = texelFetch(texFinal, iuv, 0).rgb * 1000.0;

    float exposureF = clamp(Scene_AvgExposure, Scene_PostExposureMin, Scene_PostExposureMax);
    ApplyAutoExposure(color, exposureF);

    color = LINEAR_RGB_TO_REC2020 * color;

    //color = tonemap_jodieReinhard(color);
    //color = tonemap_Lottes(color);
    //color = tonemap_ACESFit2(color);
    //color = tonemap_AgX(color);
    color = tonemap_Uchimura(color);
    //color = tonemap_Commerce(color);

    //color = color / (color + 0.155) * 1.019;

    if (Post_PurkinjeStrength > EPSILON) {
        float avg_ev = log2(max(Scene_AvgExposure, 1.0e-8));
        float ev_norm = saturate(unmix(avg_ev, -1.0, 8.0));
        float purkinje_strength = mix(0.5, 0.3, ev_norm);
        color = PurkinjeShift(color, purkinje_strength); // Post_PurkinjeStrength
    }

    color = REC2020_TO_SRGB * color;

    outColor = vec4(color, 1.0);
}
