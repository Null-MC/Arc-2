#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texFinal;
uniform sampler2D texParticles;
uniform sampler2D translucentDepthTex;
uniform sampler2D texDeferredTrans_Color;
uniform usampler2D texDeferredTrans_Data;

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
#include "/lib/csm.glsl"
#include "/lib/fresnel.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/shadow/sample.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 colorFinal = texelFetch(texFinal, iuv, 0).rgb;
    vec4 colorTrans = texelFetch(texDeferredTrans_Color, iuv, 0);

    if (colorTrans.a > EPSILON) {
        uvec2 data = texelFetch(texDeferredTrans_Data, iuv, 0).rg;
        float depth = texelFetch(translucentDepthTex, iuv, 0).r;

        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
        vec3 localPos = mul3(playerModelViewInverse, viewPos);

        colorTrans.rgb = RgbToLinear(colorTrans.rgb);

        vec4 normalMaterial = unpackUnorm4x8(data.r);
        vec3 localNormal = normalize(normalMaterial.xyz * 2.0 - 1.0);
        int material = int(normalMaterial.w * 255.0 + 0.5);

        vec2 lmCoord = unpackUnorm4x8(data.g).xy;
        lmCoord = pow(lmCoord, vec2(3.0));

        bool isWater = bitfieldExtract(material, 6, 1) != 0;
        float emission = 0.0; // (material & 8) != 0 ? 1.0 : 0.0;

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

        vec4 finalColor = colorTrans;
        finalColor.rgb *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

        if (isWater) {
            vec3 localViewDir = normalize(localPos);
            vec3 localReflectDir = reflect(localViewDir, localNormal);

            vec3 skyReflectColor = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localReflectDir, sunDir);
            finalColor.rgb = lmCoord.y * skyReflectColor;

            float NoVm = max(dot(localNormal, -localViewDir), 0.0);
            float F = F_schlick(NoVm, 0.02, 1.0);

            float specular = max(dot(localReflectDir, localLightDir), 0.0);
            finalColor.rgb += 20.0 * NoLm * skyTransmit * shadowSample * pow(specular, 64.0);
            finalColor.a = F;
        }

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // finalColor = mix(finalColor, vec4(fogColor.rgb, 1.0), fogF);

        if (isWater) {
            colorFinal = mix(colorFinal, finalColor.rgb, finalColor.a);
        }
        else {
            colorFinal *= mix(vec3(1.0), colorTrans.rgb, sqrt(colorTrans.a));
        }
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    vec4 weather = textureLod(texParticles, uv, 0);
    colorFinal = mix(colorFinal, weather.rgb, weather.a);

    outColor = vec4(colorFinal, 1.0);
}
