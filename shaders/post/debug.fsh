#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
uniform sampler2D texDiffuseAccum;

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
#endif

#ifdef DEBUG_SSGIAO
    uniform sampler2D texExposure;
    uniform sampler2D TEX_SSGIAO;
#endif

in vec2 uv;

#include "/lib/common.glsl"

#ifdef DEBUG_SSGIAO
    #include "/lib/exposure.glsl"
    #include "/lib/tonemap.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;

    // color = textureLod(texShadow_final, uv, 0).rrr;
    // color = color / (1.0 + color);
    
    if (!guiHidden) {
        #ifdef DEBUG_HISTOGRAM
            vec2 previewCoord = (uv - 0.01) / vec2(0.2, 0.1);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
                color = vec3(step(previewCoord.y*previewCoord.y, sampleVal / (screenSize.x*screenSize.y)));
            }
        #endif
        
        #ifdef DEBUG_SSGIAO
            vec2 previewCoord = (uv - 0.01) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                color = textureLod(TEX_SSGIAO, previewCoord, 0).rgb;

                ApplyAutoExposure(color, texExposure);
                color = tonemap_ACESFit2(color);
            }

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                color = textureLod(TEX_SSGIAO, previewCoord, 0).aaa;
            }
        #endif

        // vec2 previewCoord = (uv - 0.01) / vec2(0.25);
        // if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
        //     color = textureLod(texDiffuseAccum, previewCoord, 0).rgb;
        // }
    }

    outColor = vec4(color, 1.0);
}
