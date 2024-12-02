#version 430

layout(location = 0) out vec4 outColor;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localOffset;
in vec3 localNormal;
in vec3 shadowViewPos;
flat in int material;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;
uniform sampler2DArray solidShadowMap;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/erp.glsl"
#include "/lib/fresnel.glsl"
#include "/lib/csm.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/noise/ign.glsl"
#include "/lib/shadow/sample.glsl"
#include "/lib/water_waves.glsl"


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    bool isWater = false;
    float emission = 0.0;
    vec3 _localNormal = normalize(localNormal);
    vec3 localViewDir = normalize(localPos);

    #ifdef RENDER_TRANSLUCENT
        isWater = (material & 64) != 0;

        #ifdef ENABLE_WATER_WAVES
            if (isWater) {
                // albedo.rgb = vec3(0.0, 0.2, 0.8);

                const float lmcoord_y = 1.0;

                vec3 waveOffset = GetWaveHeight(localPos + cameraPos, lmcoord_y, timeCounter, 24);

                // mUV += 0.1*waveOffset.xz;

                vec3 wavePos = localPos;
                wavePos.y += waveOffset.y - localOffset.y;

                vec3 dX = dFdx(wavePos);
                vec3 dY = dFdy(wavePos);
                _localNormal = normalize(cross(dX, dY));
            }
        #endif
    #else
        emission = (material & 8) != 0 ? 1.0 : 0.0;
    #endif

    vec4 albedo = iris_sampleBaseTex(mUV);
    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;
    albedo.rgb = RgbToLinear(albedo.rgb);

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    lmcoord = pow(lmcoord, vec2(3.0));

    float shadowSample = SampleShadows();

    vec3 localLightDir = normalize(mul3(playerModelViewInverse, shadowLightPosition));
    float NoLm = step(0.0, dot(localLightDir, _localNormal));

    vec3 skyPos = getSkyPosition(localPos);
    vec3 sunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);
    vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sunDir);
    vec3 skyLighting = lmcoord.y * NoLm * skyTransmit * shadowSample;

    vec2 skyIrradianceCoord = DirectionToUV(_localNormal);
    skyLighting += 0.3 * lmcoord.y * textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    vec3 blockLighting = vec3(lmcoord.x);

    vec4 finalColor = albedo;
    finalColor.rgb *= (5.0 * skyLighting) + (3.0 * blockLighting) + (12.0 * emission) + 0.002;

    if (isWater) {
        // TODO: specular
        vec3 localReflectDir = reflect(localViewDir, _localNormal);

        // vec3 skyPos = getSkyPosition(localPos);
        vec3 skyReflectColor = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localReflectDir, sunDir);
        finalColor.rgb = skyReflectColor;

        float NoVm = max(dot(_localNormal, -localViewDir), 0.0);
        float F = F_schlick(NoVm, 0.02, 1.0);

        float specular = max(dot(localReflectDir, localLightDir), 0.0);
        finalColor.rgb += 20.0 * NoLm * skyTransmit * shadowSample * pow(specular, 64.0);
        finalColor.a = F * 0.5 + 0.5;
    }

    float viewDist = length(localPos);
    float fogF = smoothstep(fogStart, fogEnd, viewDist);
    finalColor = mix(finalColor, vec4(fogColor.rgb, 1.0), fogF);

    // finalColor.rgb = _localNormal * 0.5 + 0.5;
    // finalColor.a = 1.0;

    outColor = finalColor;
}
