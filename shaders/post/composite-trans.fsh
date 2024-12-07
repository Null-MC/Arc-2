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
#include "/lib/depth.glsl"
#include "/lib/fresnel.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"

#include "/lib/ssr.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
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

            int shadowCascade;
            vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowCascade);
            shadowSample = SampleShadows(shadowPos, shadowCascade);
        #endif

        vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);
        // float NoLm = step(0.0, dot(localLightDir, localTexNormal));
        float NoLm = max(dot(localLightDir, localGeoNormal), 0.0);

        vec3 skyPos = getSkyPosition(localPosTrans);
        vec3 sunDir = normalize(mat3(playerModelViewInverse) * sunPosition);
        vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
        vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -sunDir);
        vec3 skyLighting = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;
        skyLighting *= NoLm * shadowSample;

        vec2 skyIrradianceCoord = DirectionToUV(localTexNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLighting += (SKY_AMBIENT * lmCoord.y * SKY_BRIGHTNESS) * skyIrradiance;

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * lmCoord.x;

        vec4 finalColor = colorTrans;
        finalColor.rgb *= skyLighting
            + (BLOCKLIGHT_BRIGHTNESS * blockLighting)
            + (EMISSION_BRIGHTNESS * emission)
            + 0.0016;

        if (isWater) {
            float viewDist = length(localPosTrans);
            vec3 localViewDir = localPosTrans / viewDist;
            vec3 reflectLocalDir = reflect(localViewDir, localTexNormal);
            vec3 reflectViewDir = mat3(playerModelView) * reflectLocalDir;

            vec3 skyReflectColor = lmCoord.y * SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, sunDir);

            vec3 starViewDir = getStarViewDir(reflectLocalDir);
            vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);
            skyReflectColor += starLight;

            float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);
            float F = F_schlick(NoVm, 0.02, 1.0);

            // SSR
            vec3 reflectViewPos = viewPosTrans + 0.5*viewDist*reflectViewDir;
            vec3 reflectClipPos = unproject(playerProjection, reflectViewPos) * 0.5 + 0.5;

            vec3 clipPos = ndcPosTrans * 0.5 + 0.5;
            vec3 reflectRay = normalize(reflectClipPos - clipPos);

            vec4 reflection = GetReflectionPosition(mainDepthTex, clipPos, reflectRay);
            vec3 reflectColor = GetRelectColor(texFinalOpaque, reflection.xy, reflection.a, 0.0);

            skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);

            finalColor.rgb = F * skyReflectColor;

            // vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -sunDir);

            vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, sunDir) * sunTransmit;
            vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -sunDir) * moonTransmit;
            vec3 specular = shadowSample * (reflectSun + reflectMoon);

            finalColor.rgb += F * specular;
            finalColor.a = min(F + maxOf(specular), 1.0);
        }

        // Refraction
        vec3 refractViewNormal = mat3(playerModelView) * (localTexNormal - localGeoNormal);

        const float refractEta = (IOR_AIR/IOR_WATER);
        const vec3 refractViewDir = vec3(0.0, 0.0, 1.0);
        vec3 refractDir = refract(refractViewDir, refractViewNormal, refractEta);

        float linearDist = length(localPosOpaque - localPosTrans);

        vec2 refractMax = vec2(0.2);
        refractMax.x *= screenSize.x / screenSize.y;
        vec2 refraction = clamp(vec2(0.025 * linearDist), -refractMax, refractMax) * refractDir.xy;

        const int REFRACTION_STEPS = 8;
        vec2 refractStep = refraction / REFRACTION_STEPS;
        vec2 refract_uv = uv;

        for (int i = 0; i < REFRACTION_STEPS; i++) {
            vec2 sample_uv = refract_uv + refractStep;
            float sample_depth = textureLod(solidDepthTex, sample_uv, 0).r;

            if (depthTrans > sample_depth) break;
            refract_uv = sample_uv;
        }

        colorFinal = textureLod(texFinalOpaque, refract_uv, 0).rgb;

        // Fog
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
