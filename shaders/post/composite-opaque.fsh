#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler2D texShadow_final;
uniform sampler2D texSSGIAO_final;

#ifdef EFFECT_VL_ENABLED
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/erp.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/fresnel.glsl"
#include "/lib/light/diffuse.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"

#include "/lib/volumetric.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;
    vec4 colorOpaque = texelFetch(texDeferredOpaque_Color, iuv, 0);
    vec3 colorFinal;

    vec3 sunDir = normalize(mat3(playerModelViewInverse) * sunPosition);

    float depthOpaque = 1.0;
    if (colorOpaque.a > EPSILON) {
        depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
    }

    vec3 ndcPos = vec3(uv, depthOpaque) * 2.0 - 1.0;

    #ifdef EFFECT_TAA_ENABLED
        unjitter(ndcPos);
    #endif

    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localViewDir = normalize(localPos);

    if (colorOpaque.a > EPSILON) {
        uvec3 data = texelFetch(texDeferredOpaque_Data, iuv, 0).rgb;
        uint data_trans_g = texelFetch(texDeferredTrans_Data, iuv, 0).g;

        #ifdef EFFECT_GIAO_ENABLED
            vec4 gi_ao = textureLod(texSSGIAO_final, uv, 0);
        #else
            const vec4 gi_ao = vec4(vec3(0.0), 1.0);
        #endif

        colorOpaque.rgb = RgbToLinear(colorOpaque.rgb);

        float data_trans_water = unpackUnorm4x8(data_trans_g).b;
        bool isWet = isEyeInWater == 1
            ? depthTrans >= depthOpaque
            : depthTrans < depthOpaque && data_trans_water > 0.5;

        if (isWet) colorOpaque.rgb = pow(colorOpaque.rgb, vec3(1.8));

        vec4 normalMaterial = unpackUnorm4x8(data.r);
        vec3 localNormal = normalize(normalMaterial.xyz * 2.0 - 1.0);
        int material = int(normalMaterial.w * 255.0 + 0.5);

        vec2 lmCoord = unpackUnorm4x8(data.g).xy;
        lmCoord = lmCoord*lmCoord*lmCoord; //pow(lmCoord, vec2(3.0));
        // lmCoord = lmCoord*lmCoord;

        // TODO: bitfieldExtract()
        float sss = 0.0;//bitfieldExtract(material, 2, 1) != 0 ? 1.0 : 0.0;
        float emission = bitfieldExtract(material, 3, 1) != 0 ? 1.0 : 0.0;
        emission *= lmCoord.x;

        // colorOpaque.rgb = vec3(material / 255.0);
        // colorOpaque.rgb = vec3(emission, sss, 0.0);

        vec3 localLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);
        // float NoLm = step(0.0, dot(localLightDir, localNormal));

        vec3 H = normalize(localLightDir + -localViewDir);

        float NoLm = max(dot(localNormal, localLightDir), 0.0);
        float LoHm = max(dot(localLightDir, H), 0.0);
        float NoVm = max(dot(localNormal, -localViewDir), 0.0);

        NoLm = mix(NoLm, 1.0, sss);

        float shadowSample = NoLm;
        #ifdef SHADOWS_ENABLED
            shadowSample = textureLod(texShadow_final, uv, 0).r;
        #endif

        const float roughL = 0.9;

        vec3 skyPos = getSkyPosition(localPos);
        vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
        vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -sunDir);
        vec3 skyLighting = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;


        float worldY = localPos.y + cameraPos.y;
        float transmitF = mix(VL_Transmit, VL_RainTransmit, rainStrength);
        float lightAtmosDist = max(SEA_LEVEL + 200.0 - worldY, 0.0) / localLightDir.y;
        skyLighting *= exp2(-lightAtmosDist * transmitF);


        skyLighting *= shadowSample * diffuse(NoVm, NoLm, LoHm, roughL);

        vec2 skyIrradianceCoord = DirectionToUV(localNormal);
        vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
        skyLighting += (SKY_AMBIENT * lmCoord.y * SKY_BRIGHTNESS) * skyIrradiance * gi_ao.w;

        skyLighting += gi_ao.rgb;

        vec3 blockLighting = blackbody(BLOCKLIGHT_TEMP) * lmCoord.x;

        colorFinal = colorOpaque.rgb;
        colorFinal *= skyLighting
            + (BLOCKLIGHT_BRIGHTNESS * blockLighting)
            + (EMISSION_BRIGHTNESS * emission)
            + 0.0016;

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }
    else {
        // vec3 moonDir = normalize(mat3(playerModelViewInverse) * moonPosition);
        
        vec3 skyPos = getSkyPosition(vec3(0.0));
        colorFinal = SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, localViewDir, sunDir);

        if (rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) < 0.0) {
            float sunLum = SUN_LUMINANCE * sun(localViewDir, sunDir);
            float moonLum = MOON_LUMINANCE * moon(localViewDir, -sunDir);

            vec3 starViewDir = getStarViewDir(localViewDir);
            vec3 starLight = STAR_LUMINANCE * GetStarLight(starViewDir);

            vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, localViewDir);

            colorFinal += (sunLum + moonLum + starLight) * skyTransmit;
        }
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal = colorFinal * vlTransmit + vlScatter;
    #endif

    outColor = vec4(colorFinal, 1.0);
}
