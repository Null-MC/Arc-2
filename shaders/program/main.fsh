#version 430

layout(location = 0) out vec4 outColor;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localNormal;
in vec3 shadowViewPos;
flat in int material;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;
uniform sampler2DArray solidShadowMap;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/erp.glsl"
#include "/lib/csm.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/noise/ign.glsl"


float SampleShadows() {
    vec3 shadowPos;
    int shadowCascade;
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
    shadowPos = shadowPos * 0.5 + 0.5;

    float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    const float pixelRadius = 2.0 / shadowMapResolution;

    float shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        vec2 pcfDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcfDiskOffset) * pixelRadius;
        vec3 shadowCoord = vec3(shadowPos.xy + pixelOffset, shadowCascade);

        float shadowDepth = textureLod(solidShadowMap, shadowCoord, 0).r;
        float shadowSample = step(shadowPos.z - 0.000006, shadowDepth);
        shadowFinal += shadowSample;
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);
    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;
    albedo.rgb = RgbToLinear(albedo.rgb);

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    // vec4 specular = iris_sampleSpecular(mUV);
    // float emission = specular.a * step(specular.a, 253.5/255.0);
    float emission = (material & 8) != 0 ? 1.0 : 0.0;

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    lmcoord = pow(lmcoord, vec2(3.0));

    vec3 _localNormal = normalize(localNormal);

    float shadowSample = SampleShadows();

    vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
    float NoLm = step(0.0, dot(localLightDir, _localNormal));

    vec3 skyPos = getSkyPosition(localPos);
    vec3 sunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);
    vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, sunDir) + 0.02;
    skyLighting *= lmcoord.y * NoLm * shadowSample;

    vec2 skyIrradianceCoord = DirectionToUV(_localNormal);
    skyLighting += 0.3 * lmcoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    vec3 blockLighting = vec3(lmcoord.x);

    vec4 finalColor = albedo;
    finalColor.rgb *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

    outColor = finalColor;
}
