#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texFinal;
uniform sampler2D solidDepthTex;
uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;

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
#include "/lib/csm.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/shadow/sample.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 colorFinal = texelFetch(texFinal, iuv, 0).rgb;
    vec4 colorOpaque = texelFetch(texDeferredOpaque_Color, iuv, 0);

    if (colorOpaque.a > EPSILON) {
        uvec2 data = texelFetch(texDeferredOpaque_Data, iuv, 0).rg;
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

        vec3 shadowViewPos = mul3(shadowModelView, localPos);
        float shadowSample = SampleShadows(shadowViewPos);

        vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
        float NoLm = step(0.0, dot(localLightDir, localNormal));

        vec3 skyPos = getSkyPosition(localPos);
        vec3 sunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);
        vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
        vec3 skyLighting = lmCoord.y * NoLm * skyTransmit * shadowSample;

        vec2 skyIrradianceCoord = DirectionToUV(localNormal);
        skyLighting += 0.3 * lmCoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

        vec3 blockLighting = vec3(lmCoord.x);

        colorFinal = colorOpaque.rgb;
        colorFinal *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    outColor = vec4(colorFinal, 1.0);
}