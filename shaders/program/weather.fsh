#version 430

layout(location = 0) out vec4 outColor;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
// in vec3 localNormal;
in vec3 shadowViewPos;
// flat in int material;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray solidShadowMap;
#endif

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/ign.glsl"
#include "/lib/erp.glsl"
#include "/lib/csm.glsl"

#include "/lib/sky/common.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/sample.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    albedo.a *= 1.0 - smoothstep(cloudHeight - 16.0, cloudHeight + 16.0, localPos.y + cameraPos.y);

    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;
    albedo.rgb = RgbToLinear(albedo.rgb);

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    // float emission = (material & 8) != 0 ? 1.0 : 0.0;
    const float emission = 0.0;

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    lmcoord = pow(lmcoord, vec2(3.0));

    // vec3 _localNormal = normalize(localNormal);

    float shadowSample = 1.0;
    #ifdef SHADOWS_ENABLED
        shadowSample = SampleShadows(shadowViewPos);
    #endif

    vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
    const float NoLm = 1.0; //step(0.0, dot(localLightDir, _localNormal));

    vec3 skyPos = getSkyPosition(localPos);
    vec3 sunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);
    vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
    skyLighting *= lmcoord.y * NoLm * shadowSample;

    vec2 skyIrradianceCoord = DirectionToUV(vec3(0.0, 1.0, 0.0));
    skyLighting += 0.2 * lmcoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    vec3 blockLighting = vec3(lmcoord.x);

    vec4 finalColor = albedo;
    finalColor.rgb *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

    float viewDist = length(localPos);
    float fogF = smoothstep(fogStart, fogEnd, viewDist);
    finalColor.rgb = mix(finalColor.rgb, fogColor.rgb, fogF);

    outColor = finalColor;
}
