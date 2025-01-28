#version 430

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

in VertexData2 {
    vec2 uv;
    vec2 light;
    vec4 color;
    vec3 localPos;
    vec3 shadowViewPos;
} vIn;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler2D texFinalPrevious;
uniform sampler2D texBloom;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowColor;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/noise/ign.glsl"
#include "/lib/erp.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/blackbody.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"

#include "/lib/light/sky.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vIn.light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    albedo.a *= 1.0 - smoothstep(cloudHeight - 16.0, cloudHeight + 16.0, vIn.localPos.y + ap.camera.pos.y);

    if (iris_discardFragment(albedo)) {discard; return;}

    // albedo *= mColor;
    // albedo.rgb = RgbToLinear(albedo.rgb);

    // #ifdef DEBUG_WHITE_WORLD
    //     albedo.rgb = vec3(1.0);
    // #endif

    // // float emission = (material & 8) != 0 ? 1.0 : 0.0;
    // const float emission = 0.0;

    // vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    // lmcoord = pow(lmcoord, vec2(3.0));

    // // vec3 _localNormal = normalize(localNormal);

    // vec3 skyLight = vec3(0.0);//GetSkyLight(vIn.localPos);

     vec3 shadowSample = vec3(1.0);
     #ifdef SHADOWS_ENABLED
         int shadowCascade;
         vec3 shadowPos = GetShadowSamplePos(vIn.shadowViewPos, Shadow_MaxPcfSize, shadowCascade);
         shadowSample = SampleShadowColor_PCSS(shadowPos, shadowCascade);
     #endif

    // // vec3 skyPos = getSkyPosition(vIn.localPos);
    // // vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    // vec3 skyLighting = lmcoord.y * shadowSample * skyLight;

    // vec2 skyIrradianceCoord = DirectionToUV(vec3(0.0, 1.0, 0.0));
    // skyLighting += lmcoord.y * SKY_AMBIENT * SKY_BRIGHTNESS * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    // vec3 blockLighting = BLOCKLIGHT_BRIGHTNESS * blackbody(BLOCKLIGHT_TEMP) * lmcoord.x;

    // vec4 finalColor = albedo;
    // finalColor.rgb *= skyLighting + blockLighting + (EMISSION_BRIGHTNESS * emission) + 0.002;

    vec4 finalColor = albedo;

    float viewDist = length(vIn.localPos);
    float lod = 6.0 / (viewDist*0.1 + 1.0);

    vec2 uv = gl_FragCoord.xy / ap.game.screenSize;
    finalColor.rgb = textureLod(texFinalPrevious, uv, lod).rgb;
    finalColor.a = 1.0;

    finalColor.rgb += textureLod(texBloom, uv, 0).rgb;

    vec3 localViewDir = normalize(vIn.localPos);
    float VoLm_sun = max(dot(localViewDir, Scene_LocalSunDir), 0.0);
    float VoLm_moon = max(dot(localViewDir, -Scene_LocalSunDir), 0.0);

    vec3 sunTransmit, moonTransmit;
    GetSkyLightTransmission(vIn.localPos, sunTransmit, moonTransmit);

    finalColor.rgb += 0.1 * shadowSample * DHG(VoLm_sun, 0.88, -0.12, 0.7) * SUN_BRIGHTNESS * sunTransmit;
    //finalColor.rgb += HG(VoLm_moon, 0.8) * MOON_BRIGHTNESS * moonTransmit;

    // float viewDist = length(vIn.localPos);
    // float fogF = smoothstep(fogStart, fogEnd, viewDist);
    // finalColor.rgb = mix(finalColor.rgb, fogColor.rgb, fogF);

    outColor = finalColor;
}
