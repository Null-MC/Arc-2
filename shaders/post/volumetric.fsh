#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texFinal;
uniform sampler2D texSkyTransmit;
uniform sampler2D solidDepthTex;
// uniform sampler2D shadowtex0;
uniform sampler2DArray solidShadowMap;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/noise/ign.glsl"
#include "/lib/hg.glsl"
#include "/lib/csm.glsl"
#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"


const int VL_MaxSamples = 32;
const float VL_Scatter = 0.006;
const float VL_Transmit = 0.002;


void main() {
    vec3 color = textureLod(texFinal, uv, 0).rgb;

    float stepScale = 1.0 / VL_MaxSamples;

    float depth = textureLod(solidDepthTex, uv, 0).r;
    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);
    vec3 stepLocal = localPos * stepScale;

    vec3 shadowViewStart = mul3(shadowModelView, vec3(0.0));
    vec3 shadowViewEnd = mul3(shadowModelView, localPos);
    vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

    float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    vec3 localSunDir = normalize((playerModelViewInverse * vec4(sunPosition, 1.0)).xyz);

    vec3 localViewDir = normalize(localPos);
    float VoL = dot(localViewDir, localSunDir);
    float phase = HG(VoL, 0.46);

    float stepDist = length(stepLocal);

    for (int i = 0; i < VL_MaxSamples; i++) {
        vec3 shadowViewPos = shadowViewStep*(i+dither) + shadowViewStart;

        vec3 shadowPos;
        int shadowCascade;
        GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
        shadowPos = shadowPos * 0.5 + 0.5;

        vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
        float shadowDepth = textureLod(solidShadowMap, shadowCoord, 0).r;
        float shadowSample = step(shadowPos.z - 0.000006, shadowDepth);

        if (clamp(shadowPos, 0.0, 1.0) != shadowPos) shadowSample = 1.0;

        vec3 sampleLocalPos = (i+dither) * stepLocal;

        vec3 skyPos = getSkyPosition(sampleLocalPos);
        vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, localSunDir);
        vec3 sampleColor = 5.0 * skyLighting * shadowSample;

        float sampleY = sampleLocalPos.y + cameraPos.y;
        float sampleDensity = clamp((sampleY - SEA_LEVEL) / (ATMOSPHERE_MAX - SEA_LEVEL), 0.0, 1.0);
        sampleDensity = stepDist * pow(1.0 - sampleDensity, 8.0);

        color *= exp(-sampleDensity * VL_Transmit);
        color += sampleColor * (phase * sampleDensity * VL_Scatter);
    }

    outColor = vec4(color, 1.0);
}
