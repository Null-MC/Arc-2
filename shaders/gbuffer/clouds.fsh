#version 430

layout(location = 0) out vec4 outColor;

in vec2 uv;
// in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localNormal;
// in vec3 shadowViewPos;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/erp.glsl"

#include "/lib/sky/common.glsl"


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = vec2(1.0);// light;
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

    vec4 colorFinal = albedo;
    const float shadowSample = 1.0;

    float NoLm = step(0.0, dot(Scene_LocalLightDir, _localNormal));

    vec3 skyPos = getSkyPosition(localPos);
    vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    vec3 skyLighting = NoLm * skyTransmit * shadowSample;

    vec2 skyIrradianceCoord = DirectionToUV(_localNormal);
    skyLighting += 0.3 * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    colorFinal.rgb *= (5.0 * skyLighting) + 0.002;

    outColor = colorFinal;
}
