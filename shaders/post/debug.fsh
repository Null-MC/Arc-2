#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

uniform sampler2D texFinal;

#if DEBUG_VIEW == DEBUG_VIEW_SHADOWS
    uniform sampler2D TEX_SHADOW;
#elif DEBUG_VIEW == DEBUG_VIEW_SSS
    uniform sampler2D TEX_SHADOW;
#elif DEBUG_VIEW == DEBUG_VIEW_SSAO
    uniform sampler2D TEX_SSAO;
    uniform sampler2D TEX_ACCUM_OCCLUSION;
#elif DEBUG_VIEW == DEBUG_VIEW_VL
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#elif DEBUG_VIEW == DEBUG_VIEW_RT
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
#elif DEBUG_VIEW == DEBUG_VIEW_ACCUMULATION
    #ifdef DEBUG_TRANSLUCENT
        uniform sampler2D texAccumDiffuse_translucent;
        uniform sampler2D texAccumSpecular_translucent;
    #else
        uniform sampler2D texAccumDiffuse_opaque;
        uniform sampler2D texAccumSpecular_opaque;
    #endif
#elif DEBUG_VIEW == DEBUG_VIEW_SKY_IRRADIANCE
    uniform sampler2D texSkyView;
    uniform sampler2D texSkyIrradiance;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOWMAP_COLOR
    uniform sampler2DArray texShadowColor;
#elif DEBUG_VIEW == DEBUG_VIEW_SHADOWMAP_NORMAL
    uniform sampler2DArray texShadowNormal;
#endif

#if DEBUG_VIEW == DEBUG_VIEW_MATERIAL
    uniform sampler2D TEX_COLOR;
    uniform sampler2D TEX_NORMAL;
    uniform usampler2D TEX_DATA;
#endif

#ifdef DEBUG_HISTOGRAM
    uniform usampler2D texHistogram_debug;
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
    #include "/lib/buffers/quad-list.glsl"
#endif

#include "/lib/exposure.glsl"
#include "/lib/tonemap.glsl"

#include "/lib/utility/text.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 color = texelFetch(texFinal, iuv, 0).rgb;
    vec2 previewCoord, previewCoord2, previewCoordSq;
    
    if (!ap.game.guiHidden) {
        float aspect = ap.game.screenSize.y / ap.game.screenSize.x;

        previewCoord = (uv - 0.01) / vec2(0.25);
        previewCoord2 = (uv - vec2(0.27, 0.01)) / vec2(0.25);
        previewCoordSq = (uv - 0.01) / vec2(0.25 * aspect, 0.25);

        if (saturate(previewCoord) == previewCoord) {
            #if DEBUG_VIEW == DEBUG_VIEW_SHADOWS
                color = textureLod(TEX_SHADOW, previewCoord, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_SSS
                color = textureLod(TEX_SHADOW, previewCoord, 0).aaa;
            #elif DEBUG_VIEW == DEBUG_VIEW_SSAO
                color = textureLod(TEX_SSAO, previewCoord, 0).rrr;
            #elif DEBUG_VIEW == DEBUG_VIEW_VL
                color = textureLod(texScatterVL, previewCoord, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_RT
                color = textureLod(texDiffuseRT, previewCoord, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_ACCUMULATION
                #ifdef DEBUG_TRANSLUCENT
                    color = textureLod(texAccumDiffuse_translucent, previewCoord, 0).rgb;
                #else
                    color = textureLod(texAccumDiffuse_opaque, previewCoord, 0).rgb;
                #endif
            #elif DEBUG_VIEW == DEBUG_VIEW_SKY_IRRADIANCE
                color = textureLod(texSkyView, previewCoord, 0).rgb * 0.001;
                //ApplyAutoExposure(color, Scene_AvgExposure);
                color = tonemap_jodieReinhard(color);
            #endif

            #if DEBUG_VIEW == DEBUG_VIEW_MATERIAL
                #if DEBUG_MATERIAL == DEBUG_MAT_ALBEDO
                    color = textureLod(TEX_COLOR, previewCoord, 0).rgb;
                #elif DEBUG_MATERIAL == DEBUG_MAT_GEO_NORMAL
                    uint data_r = textureLod(TEX_DATA, previewCoord, 0).r;
                    color = unpackUnorm4x8(data_r).rgb;
                #elif DEBUG_MATERIAL == DEBUG_MAT_TEX_NORMAL
                    color = textureLod(TEX_NORMAL, previewCoord, 0).rgb;
                #elif DEBUG_MATERIAL == DEBUG_MAT_OCCLUSION
                    uint data_b = textureLod(TEX_DATA, previewCoord, 0).b;
                    color = unpackUnorm4x8(data_b).bbb;
                #elif DEBUG_MATERIAL == DEBUG_MAT_ROUGH
                    uint data_g = textureLod(TEX_DATA, previewCoord, 0).g;
                    color = unpackUnorm4x8(data_g).rrr;
                #elif DEBUG_MATERIAL == DEBUG_MAT_F0_METAL
                    uint data_g = textureLod(TEX_DATA, previewCoord, 0).g;
                    color = unpackUnorm4x8(data_g).ggg;
                #elif DEBUG_MATERIAL == DEBUG_MAT_POROSITY
                    //uint data_g = textureLod(TEX_DATA, previewCoord, 0).g;
                    //color = unpackUnorm4x8(data_g).ggg;
                #elif DEBUG_MATERIAL == DEBUG_MAT_SSS
                    uint data_g = textureLod(TEX_DATA, previewCoord, 0).g;
                    color = unpackUnorm4x8(data_g).aaa;
                #elif DEBUG_MATERIAL == DEBUG_MAT_EMISSION
                    uint data_g = textureLod(TEX_DATA, previewCoord, 0).g;
                    color = unpackUnorm4x8(data_g).bbb;
                #elif DEBUG_MATERIAL == DEBUG_MAT_LMCOORD
                    uint data_b = textureLod(TEX_DATA, previewCoord, 0).b;
                    color = vec3(unpackUnorm4x8(data_b).xy, 0.0).xzy;
                #endif
            #endif
        }

        if (saturate(previewCoord2) == previewCoord2) {
            #if DEBUG_VIEW == DEBUG_VIEW_VL
                color = textureLod(texTransmitVL, previewCoord2, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_RT
                color = textureLod(texSpecularRT, previewCoord2, 0).rgb;
            #elif DEBUG_VIEW == DEBUG_VIEW_SSAO
                color = textureLod(TEX_ACCUM_OCCLUSION, previewCoord2, 0).rrr;
            #elif DEBUG_VIEW == DEBUG_VIEW_ACCUMULATION
                #ifdef DEBUG_TRANSLUCENT
                    color = textureLod(texAccumSpecular_translucent, previewCoord2, 0).rgb;
                #else
                    color = textureLod(texAccumSpecular_opaque, previewCoord2, 0).rgb;
                #endif
            #elif DEBUG_VIEW == DEBUG_VIEW_SKY_IRRADIANCE
                color = textureLod(texSkyIrradiance, previewCoord2, 0).rgb * 0.001;
                //ApplyAutoExposure(color, Scene_AvgExposure);
                color = tonemap_jodieReinhard(color);
            #endif
        }

        if (saturate(previewCoordSq) == previewCoordSq) {
            #if DEBUG_VIEW == DEBUG_VIEW_SHADOWMAP_COLOR
                vec4 shadowColor = textureLod(texShadowColor, vec3(previewCoordSq, 0), 0);
                color = shadowColor.rgb * shadowColor.a;
            #elif DEBUG_VIEW == DEBUG_VIEW_SHADOWMAP_NORMAL
                color = textureLod(texShadowNormal, vec3(previewCoordSq, 0), 0).rgb;
            #endif
        }

        #ifdef DEBUG_HISTOGRAM
            previewCoord = (uv - 0.01) / vec2(0.25, 0.1);
            if (saturate(previewCoord) == previewCoord) {
                uint sampleVal = textureLod(texHistogram_debug, previewCoord, 0).r;
                color = vec3(step(previewCoord.y*previewCoord.y, sampleVal / (ap.game.screenSize.x*ap.game.screenSize.y)));
            }

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.04, 0.1);
            if (saturate(previewCoord) == previewCoord) {
                color = vec3(Scene_AvgExposure);
            }
        #endif

        #ifdef DEBUG_RT
            previewCoord = (uv - 0.01) / vec2(0.25);
            if (saturate(previewCoord) == previewCoord)
                color = textureLod(texDiffuseRT, previewCoord, 0).rgb;

            previewCoord = (uv - vec2(0.27, 0.01)) / vec2(0.25);
            if (saturate(previewCoord) == previewCoord)
                color = textureLod(texSpecularRT, previewCoord, 0).rgb;
        #endif

//        previewCoord = (uv - 0.01) / vec2(0.25);
//        if (clamp(previewCoord, 0.0, 1.0) == previewCoord) {
//            color = textureLod(texSpecularRT, previewCoord, 0).rgb;
//        }

        bool AccumulationEnabled = false;
        bool VoxelizationEnabled = false;

        #ifdef ACCUM_ENABLED
            AccumulationEnabled = true;
        #endif

        #ifdef VOXEL_ENABLED
            VoxelizationEnabled = true;
        #endif

        beginText(ivec2(gl_FragCoord.xy*0.5), ivec2(8, ap.game.screenSize.y*0.5-8));
        text.bgCol = vec4(0.0, 0.0, 0.0, 0.6);
        text.fgCol = vec4(0.8, 0.8, 0.8, 1.0);
        printString((_S, _e, _t, _t, _i, _n, _g, _s));
        printLine();
        printString((_minus, _minus, _minus, _minus, _minus, _minus, _minus, _minus));
        printLine();
        printString((_A, _c, _c, _u, _m, _u, _l, _a, _t, _i, _o, _n, _colon, _space));
        printBool(AccumulationEnabled);
        printLine();
        printString((_V, _o, _x, _e, _l, _i, _z, _a, _t, _i, _o, _n, _colon, _space));
        printBool(VoxelizationEnabled);
        printLine();
        //...
        endText(color);
    }



    beginText(ivec2(gl_FragCoord.xy * 0.5), ivec2(4, ap.game.screenSize.y/2 - 24));

    text.bgCol = vec4(0.0, 0.0, 0.0, 0.6);
    text.fgCol = vec4(1.0, 1.0, 1.0, 1.0);
    text.fpPrecision = 4;

    // // printString((_P, _o, _s, _i, _t, _i, _o, _n, _colon, _space));
    // // printVec3(Scene_TrackPos);
    // // printLine();

//     printString((_F, _r, _a, _m, _e, _colon, _space));
//     printUnsignedInt(ap.time.frames);
//     printLine();

    #if LIGHTING_MODE == LIGHT_MODE_RT && defined(DEBUG_RT)
        printString((_L, _i, _g, _h, _t, _s, _colon, _space));
        printUnsignedInt(Scene_LightCount);
        printLine();
    #endif

    #ifdef VOXEL_TRI_ENABLED
        printString((_Q, _u, _a, _d, _s, _colon, _space));
        printUnsignedInt(SceneQuads.total);
        printLine();
    #endif

    endText(color);

    outColor = vec4(color, 1.0);
}
