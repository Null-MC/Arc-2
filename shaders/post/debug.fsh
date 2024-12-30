#version 430 core
#extension GL_NV_gpu_shader5: enable

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;

#if DEBUG_VIEW == DEBUG_VIEW_SHADOWS
    uniform sampler2D TEX_SHADOW;
#elif DEBUG_VIEW == DEBUG_VIEW_SSS
    uniform sampler2D TEX_SHADOW;
#endif

#if DEBUG_MATERIAL != DEBUG_MAT_NONE
    uniform sampler2D texDeferredOpaque_Color;
    uniform sampler2D texDeferredOpaque_TexNormal;
    uniform usampler2D texDeferredOpaque_Data;
#endif

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
#endif

#ifdef DEBUG_SSGIAO
    uniform sampler2D TEX_SSGIAO;
#endif

#ifdef DEBUG_RT
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#endif

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT
    #include "/lib/buffers/light-list.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/triangle-list.glsl"
#endif

#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

#include "/lib/utility/text.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    vec2 previewCoord;
    
    if (!guiHidden) {
        previewCoord = (uv - 0.01) / vec2(0.25);

        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
            #if DEBUG_VIEW == DEBUG_VIEW_SHADOWS
                color = textureLod(TEX_SHADOW, previewCoord, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_SSS
                color = textureLod(TEX_SHADOW, previewCoord, 0).aaa;
            #endif

            #if DEBUG_MATERIAL == DEBUG_MAT_ALBEDO
                color = textureLod(texDeferredOpaque_Color, previewCoord, 0).rgb;
            #elif DEBUG_MATERIAL == DEBUG_MAT_GEO_NORMAL
                uint data_r = textureLod(texDeferredOpaque_Data, previewCoord, 0).r;
                color = unpackUnorm4x8(data_r).rgb;
            #elif DEBUG_MATERIAL == DEBUG_MAT_TEX_NORMAL
                color = textureLod(texDeferredOpaque_TexNormal, previewCoord, 0).rgb;
            #elif DEBUG_MATERIAL == DEBUG_MAT_OCCLUSION
                uint data_b = textureLod(texDeferredOpaque_Data, previewCoord, 0).b;
                color = unpackUnorm4x8(data_b).bbb;
            #elif DEBUG_MATERIAL == DEBUG_MAT_ROUGH
                uint data_g = textureLod(texDeferredOpaque_Data, previewCoord, 0).g;
                color = unpackUnorm4x8(data_g).rrr;
            #elif DEBUG_MATERIAL == DEBUG_MAT_F0_METAL
                uint data_g = textureLod(texDeferredOpaque_Data, previewCoord, 0).g;
                color = unpackUnorm4x8(data_g).ggg;
            #elif DEBUG_MATERIAL == DEBUG_MAT_POROSITY
                //uint data_g = textureLod(texDeferredOpaque_Data, previewCoord, 0).g;
                //color = unpackUnorm4x8(data_g).ggg;
            #elif DEBUG_MATERIAL == DEBUG_MAT_SSS
                uint data_g = textureLod(texDeferredOpaque_Data, previewCoord, 0).g;
                color = unpackUnorm4x8(data_g).aaa;
            #elif DEBUG_MATERIAL == DEBUG_MAT_EMISSION
                uint data_g = textureLod(texDeferredOpaque_Data, previewCoord, 0).g;
                color = unpackUnorm4x8(data_g).bbb;
            #elif DEBUG_MATERIAL == DEBUG_MAT_LMCOORD
                uint data_b = textureLod(texDeferredOpaque_Data, previewCoord, 0).b;
                color = vec3(unpackUnorm4x8(data_b).xy, 0.0).xzy;
            #endif
        }

        #ifdef DEBUG_HISTOGRAM
            previewCoord = (uv - 0.01) / vec2(0.25, 0.1);
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
            previewCoord = (uv - 0.01) / vec2(0.25);
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

        #ifdef DEBUG_RT
            previewCoord = (uv - 0.01) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord)
                color = textureLod(texDiffuseRT, previewCoord, 0).rgb;

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.25);
            if (clamp(previewCoord, 0.0, 1.0) == previewCoord)
                color = textureLod(texSpecularRT, previewCoord, 0).rgb;
        #endif

//        previewCoord = (uv - 0.01) / vec2(0.25);
//        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
//            color = textureLod(texSpecularRT, previewCoord, 0).rgb;
//        }
    }

    beginText(ivec2(gl_FragCoord.xy * 0.5), ivec2(4, screenSize.y/2 - 24));

    text.bgCol = vec4(0.0, 0.0, 0.0, 0.6);
    text.fgCol = vec4(1.0, 1.0, 1.0, 1.0);
    text.fpPrecision = 4;

    // // printString((_P, _o, _s, _i, _t, _i, _o, _n, _colon, _space));
    // // printVec3(Scene_TrackPos);
    // // printLine();

//     printString((_F, _r, _a, _m, _e, _colon, _space));
//     printUnsignedInt(frameCounter);
//     printLine();

    #if LIGHTING_MODE == LIGHT_MODE_RT
        printString((_L, _i, _g, _h, _t, _s, _colon, _space));
        printUnsignedInt(Scene_LightCount);
        printLine();
    #endif

    #ifdef VOXEL_TRI_ENABLED
        printString((_T, _r, _i, _a, _n, _g, _l, _e, _s, _colon, _space));
        printUnsignedInt(Scene_TriangleCount);
        printLine();
    #endif

    endText(color);

    outColor = vec4(color, 1.0);
}
