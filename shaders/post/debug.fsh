#version 430 core

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;
uniform sampler2D texExposure;
uniform sampler2D texSSGIAO_final;

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
#endif

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/bayer.glsl"
#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    
    if (!guiHidden) {
        #ifdef DEBUG_HISTOGRAM
            vec2 previewCoord = (uv - 0.01) / vec2(0.2, 0.1);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
                uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
                color = vec3(step(previewCoord.y*previewCoord.y, sampleVal / (screenSize.x*screenSize.y)));
            }
        #endif
        
        // previewCoord = (uv - vec2(0.02, 0.42)) / 0.3;
        // if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
        //     // uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
        //     // color = vec3(1.0 - 1.0 / (sampleVal+1.0));
        //     color = texelFetch(texExposure, ivec2(0), 0).rrr;
        // }

        vec2 previewCoord = (uv - 0.01) / vec2(0.2, 0.15);
        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
            color = textureLod(texSSGIAO_final, previewCoord, 0).rgb;

            ApplyAutoExposure(color, texExposure);
            color = tonemap_ACESFit2(color);
        }

        previewCoord = (uv - vec2(0.22, 0.01)) / vec2(0.2, 0.15);
        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
            color = textureLod(texSSGIAO_final, previewCoord, 0).aaa;
        }
    }

    outColor = vec4(color, 1.0);
}
