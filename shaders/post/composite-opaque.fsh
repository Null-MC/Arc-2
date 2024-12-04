#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D solidDepthTex;
uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;
uniform sampler2DArray solidShadowMap;

#ifdef EFFECT_VL_ENABLED
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/ign.glsl"
#include "/lib/erp.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec4 colorOpaque = texelFetch(texDeferredOpaque_Color, iuv, 0);
    vec3 colorFinal;

    vec3 sunDir = normalize(mat3(playerModelViewInverse) * sunPosition);

    if (colorOpaque.a > EPSILON) {
        uvec3 data = texelFetch(texDeferredOpaque_Data, iuv, 0).rgb;
        float depth = texelFetch(solidDepthTex, iuv, 0).r;

        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPos = mul3(playerModelViewInverse, viewPos);

        colorOpaque.rgb = RgbToLinear(colorOpaque.rgb);

        vec4 normalMaterial = unpackUnorm4x8(data.r);
        vec3 localNormal = normalize(normalMaterial.xyz * 2.0 - 1.0);
        int material = int(normalMaterial.w * 255.0 + 0.5);

        vec2 lmCoord = unpackUnorm4x8(data.g).xy;
        lmCoord = pow(lmCoord, vec2(3.0));

        // TODO: bitfieldExtract()
        float emission = (material & 8) != 0 ? 1.0 : 0.0;
        emission *= lmCoord.x;

        float shadowSample = 1.0;
        #ifdef SHADOWS_ENABLED
            vec3 shadowViewPos = mul3(shadowModelView, localPos);
            shadowSample = SampleShadows(shadowViewPos);
        #endif

        vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);
        float NoLm = step(0.0, dot(localLightDir, localNormal));

        vec3 skyPos = getSkyPosition(localPos);
        vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
        vec3 skyLighting = lmCoord.y * NoLm * skyTransmit * shadowSample;

        vec2 skyIrradianceCoord = DirectionToUV(localNormal);
        skyLighting += 0.3 * lmCoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * lmCoord.x;

        colorFinal = colorOpaque.rgb;
        colorFinal *= (5.0 * skyLighting) + (2.0 * blockLighting) + (4.0 * emission) + 0.003;

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }
    else {
        vec2 uv = gl_FragCoord.xy / screenSize;
        vec3 ndcPos = vec3(uv, 1.0) * 2.0 - 1.0;
        vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPos = mul3(playerModelViewInverse, viewPos);
        vec3 localViewDir = normalize(localPos);
        
        vec3 skyPos = getSkyPosition(vec3(0.0));
        colorFinal = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localViewDir, sunDir);

        if (rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) < 0.0) {
            float sunLum = 800.0 * sun(localViewDir, sunDir);

            vec3 starViewDir = getStarViewDir(localViewDir);
            vec3 starLight = 0.4 * GetStarLight(starViewDir);

            vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, localViewDir);

            colorFinal += (sunLum + starLight) * skyTransmit;
        }
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    outColor = vec4(colorFinal, 1.0);
}
