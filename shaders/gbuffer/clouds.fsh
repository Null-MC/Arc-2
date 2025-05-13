#version 430

layout(location = 0) out vec4 outColor;

in VertexData2 {
    vec2 uv;
    vec2 light;
    vec4 color;
    vec3 localPos;
    vec3 localOffset;
    vec3 localNormal;
    vec4 localTangent;
    flat int material;
} vIn;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/erp.glsl"

#include "/lib/sky/common.glsl"


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vec2(1.0);// light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    vec3 localNormal = normalize(vIn.localNormal);

    vec4 albedo = iris_sampleBaseTex(mUV);
    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor * 0.8;
    albedo.rgb = RgbToLinear(albedo.rgb);

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    vec4 colorFinal = albedo;
    const float shadowSample = 1.0;

    float NoLm = max(dot(Scene_LocalLightDir, localNormal), 0.0);

    vec3 skyPos = getSkyPosition(vIn.localPos);
    vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
    vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;

    vec3 skyLighting = skyLight * NoLm;// * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

    vec2 skyIrradianceCoord = DirectionToUV(localNormal);
    skyLighting += SKY_AMBIENT * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    colorFinal.rgb *= skyLighting + 0.002;

    outColor = colorFinal;
}
