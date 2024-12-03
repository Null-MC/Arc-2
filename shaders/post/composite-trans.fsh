#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texFinalOpaque;
uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;
uniform sampler2D texDeferredTrans_Color;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texParticles;
uniform sampler2D texClouds;

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
#include "/lib/sky/sun.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/sample.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 colorFinal = texelFetch(texFinalOpaque, iuv, 0).rgb;
    vec4 colorTrans = texelFetch(texDeferredTrans_Color, iuv, 0);

    if (colorTrans.a > EPSILON) {
        uvec3 data = texelFetch(texDeferredTrans_Data, iuv, 0).rgb;
        float depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
        float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;

        vec3 ndcPosOpaque = vec3(uv, depthOpaque) * 2.0 - 1.0;
        vec3 ndcPosTrans = vec3(uv, depthTrans) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPosOpaque);
            unjitter(ndcPosTrans);
        #endif

        vec3 viewPosOpaque = unproject(playerProjectionInverse, ndcPosOpaque);
        vec3 localPosOpaque = mul3(playerModelViewInverse, viewPosOpaque);

        vec3 viewPosTrans = unproject(playerProjectionInverse, ndcPosTrans);
        vec3 localPosTrans = mul3(playerModelViewInverse, viewPosTrans);

        colorTrans.rgb = RgbToLinear(colorTrans.rgb);

        vec4 normalMaterial = unpackUnorm4x8(data.r);
        vec3 localGeoNormal = normalize(normalMaterial.xyz * 2.0 - 1.0);
        int material = int(normalMaterial.w * 255.0 + 0.5);

        vec2 lmCoord = unpackUnorm4x8(data.g).xy;
        lmCoord = pow(lmCoord, vec2(3.0));

        vec3 localTexNormal = normalize(unpackUnorm4x8(data.b).xyz * 2.0 - 1.0);

        bool isWater = bitfieldExtract(material, 6, 1) != 0;
        float emission = 0.0; // (material & 8) != 0 ? 1.0 : 0.0;

        float shadowSample = 1.0;
        #ifdef SHADOWS_ENABLED
            vec3 shadowViewPos = mul3(shadowModelView, localPosTrans);
            shadowSample = SampleShadows(shadowViewPos);
        #endif

        vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
        float NoLm = step(0.0, dot(localLightDir, localTexNormal));

        vec3 skyPos = getSkyPosition(localPosTrans);
        vec3 sunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);
        vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
        vec3 skyLighting = lmCoord.y * NoLm * skyTransmit * shadowSample;

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        skyLighting += 0.3 * lmCoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

        vec3 blockLighting = vec3(lmCoord.x);

        vec4 finalColor = colorTrans;
        finalColor.rgb *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

        if (isWater) {
            vec3 localViewDir = normalize(localPosTrans);
            vec3 localReflectDir = reflect(localViewDir, localTexNormal);

            vec3 skyReflectColor = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localReflectDir, sunDir);
            finalColor.rgb = lmCoord.y * skyReflectColor;

            float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);
            float F = F_schlick(NoVm, 0.02, 1.0);

            // TODO: SSR?
            // vec3 ssr_posStrength = ssr();
            // vec3 reflectColor = textureLod(texFinalPrev, );

            float specular = 80.0 * shadowSample * sun(localReflectDir, sunDir);

            finalColor.rgb += specular * skyTransmit;
            finalColor.a = min(F + specular, 1.0);
        }

        vec3 refractViewNormal = mat3(playerModelView) * (localTexNormal - localGeoNormal);

        const float refractEta = (IOR_AIR/IOR_WATER);
        const vec3 refractViewDir = vec3(0.0, 0.0, 1.0);
        vec3 refractDir = refract(refractViewDir, refractViewNormal, refractEta);

        float linearDist = length(localPosOpaque - localPosTrans);

        vec2 refractMax = vec2(0.2);
        refractMax.x *= screenSize.x / screenSize.y;
        vec2 refraction = clamp(vec2(0.025 * linearDist), -refractMax, refractMax) * refractDir.xy;

        // TODO: replace simple refract with SS march
        colorFinal = textureLod(texFinalOpaque, uv + refraction, 0).rgb;

        // float viewDist = length(localPosTrans);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // finalColor = mix(finalColor, vec4(fogColor.rgb, 1.0), fogF);

        if (isWater) {
            colorFinal = mix(colorFinal, finalColor.rgb, finalColor.a);
        }
        else {
            colorFinal *= mix(vec3(1.0), colorTrans.rgb, sqrt(colorTrans.a));
        }
    }

    vec4 clouds = textureLod(texClouds, uv, 0);
    colorFinal = mix(colorFinal, clouds.rgb, clouds.a);

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    vec4 weather = textureLod(texParticles, uv, 0);
    colorFinal = mix(colorFinal, weather.rgb, weather.a);

    outColor = vec4(colorFinal, 1.0);
}
