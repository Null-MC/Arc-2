#version 430 core

layout(location = 0) out vec3 outColor;

uniform sampler2D TEX_SRC;

// in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

#include "/lib/effects/purkinje.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(TEX_SRC, iuv, 0).rgb * BufferLumScale;

    float exposureF = clamp(Scene_AvgExposure, Scene_PostExposureMin, Scene_PostExposureMax);
    ApplyAutoExposure(color, exposureF);

    #ifdef POST_PURKINJE_ENABLED
        float avg_ev = log2(max(Scene_AvgExposure, 1.0e-8));
        float ev_norm = saturate(unmix(Scene_PostExposureMin, Scene_PostExposureMax, avg_ev));

        float purkinje_strength = 1.0 - ev_norm;
        //if (gl_FragCoord.x > ap.game.screenSize.x/2)
            color = PurkinjeShift(color, purkinje_strength);
    #endif

    color = LINEAR_RGB_TO_REC2020 * color;

    //color = tonemap_jodieReinhard(color);
    //color = tonemap_Lottes(color);
    //color = tonemap_ACESFit2(color);
    //color = tonemap_AgX(color);
    color = tonemap_Uchimura(color);
    //color = tonemap_Commerce(color);
    //color = tonemap_SEUS(color);

    //color = color / (color + 0.155) * 1.019;

    color = REC2020_TO_SRGB * color;

    outColor = color;
}
