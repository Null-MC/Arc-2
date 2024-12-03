#version 430

layout(location = 0) out vec4 outColor;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localOffset;
in vec3 localNormal;
// in vec3 shadowViewPos;
flat in int material;

// uniform sampler2D lightmap;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/erp.glsl"

#include "/lib/sky/common.glsl"


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    vec3 _localNormal = normalize(localNormal);

    vec4 albedo = iris_sampleBaseTex(mUV);
    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;
    albedo.rgb = RgbToLinear(albedo.rgb);

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    vec2 lmCoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

    vec4 colorFinal = albedo;
    const float shadowSample = 1.0;



    vec3 sunDir = normalize(mul3(playerModelViewInverse, sunPosition));
    vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
    float NoLm = step(0.0, dot(localLightDir, _localNormal));

    vec3 skyPos = getSkyPosition(localPos);
    vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
    vec3 skyLighting = NoLm * skyTransmit * shadowSample;

    vec2 skyIrradianceCoord = DirectionToUV(_localNormal);
    skyLighting += 0.3 * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    vec3 blockLighting = vec3(0.0);// vec3(lmCoord.x);

    // colorFinal = colorOpaque.rgb;
    colorFinal.rgb *= (5.0 * lmCoord.y * skyLighting) + (3.0 * blockLighting) + 0.002;

    outColor = colorFinal;
}
