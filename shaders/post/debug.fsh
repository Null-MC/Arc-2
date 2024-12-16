#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
uniform sampler2D texShadow;

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
#endif

#ifdef DEBUG_SSGIAO
    uniform sampler2D TEX_SSGIAO;
#endif

in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

#include "/lib/utility/text.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    
    if (!guiHidden) {
        #ifdef DEBUG_HISTOGRAM
            vec2 previewCoord = (uv - 0.01) / vec2(0.25, 0.1);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
                color = vec3(step(previewCoord.y*previewCoord.y, sampleVal / (screenSize.x*screenSize.y)));
            }

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.04, 0.1);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                color = vec3(Scene_AvgExposure);
            }
        #endif
        
        #ifdef DEBUG_SSGIAO
            vec2 previewCoord = (uv - 0.01) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                color = textureLod(TEX_SSGIAO, previewCoord, 0).rgb;

                ApplyAutoExposure(color, Scene_AvgExposure);
                color = tonemap_ACESFit2(color);
            }

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                color = textureLod(TEX_SSGIAO, previewCoord, 0).aaa;
            }
        #endif

        vec2 previewCoord = (uv - 0.01) / vec2(0.25);
        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
            color = textureLod(texShadow, previewCoord, 0).aaa;
            // ApplyAutoExposure(color, Scene_AvgExposure);
            // color = tonemap_ACESFit2(color);
        }
    }

    // beginText(ivec2(gl_FragCoord.xy * 0.5), ivec2(4, screenSize.y/2 - 24));

    // text.bgCol = vec4(0.0, 0.0, 0.0, 0.6);
    // text.fgCol = vec4(1.0, 1.0, 1.0, 1.0);
    // text.fpPrecision = 4;

    // // printString((_P, _o, _s, _i, _t, _i, _o, _n, _colon, _space));
    // // printVec3(Scene_TrackPos);
    // // printLine();

    // printString((_E, _x, _p, _o, _s, _u, _r, _e, _colon, _space));
    // printFloat(Scene_AvgExposure);
    // printLine();

    // printString((_F, _r, _a, _m, _e, _colon, _space));
    // printInt(frameCounter);
    // printLine();

    // endText(color);

    outColor = vec4(color, 1.0);
}
