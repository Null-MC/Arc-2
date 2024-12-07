#version 430 core

layout(location = 0) out vec4 outDiffuse;
layout(location = 1) out vec4 outDiffusePrevious;

uniform sampler2D solidDepthTex;
uniform sampler2D texDiffuseAccumPrevious;
uniform sampler2D texSSGIAO;

in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"


vec3 getReprojectedClipPos(const in vec2 texcoord, const in float depth, const in vec3 velocity) {
    vec3 clipPos = vec3(texcoord, depth) * 2.0 - 1.0;

    vec3 viewPos = unproject(playerProjectionInverse, clipPos);

    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localPosPrev = localPos - velocity + (cameraPos - lastCameraPos);

    vec3 viewPosPrev = mul3(lastPlayerModelView, localPosPrev);

    vec3 clipPosPrev = unproject(lastPlayerProjection, viewPosPrev);

    return clipPosPrev * 0.5 + 0.5;
}

void main() {
    // vec2 uv2 = uv;
    // uv2 += getJitterOffset(frameCounter);

    float depth = textureLod(solidDepthTex, uv, 0).r;

    // TODO: add velocity buffer
    vec3 velocity = vec3(0.0); //textureLod(BUFFER_VELOCITY, uv, 0).xyz;
    vec2 uvLast = getReprojectedClipPos(uv, depth, velocity).xy;

    vec4 previous = textureLod(texDiffuseAccumPrevious, uvLast, 0);

    if (clamp(uvLast, 0.0, 1.0) != uvLast) previous.a = 0.0;


    // ivec2 iuv = ivec2(gl_FragCoord.xy);
    // vec4 previous = texelFetch(texDiffuseAccumPrevious, iuv, 0);
    vec3 ssgi = textureLod(texSSGIAO, uv, 0).rgb;

    // TODO
    vec3 diffuse = ssgi;

    float counter = clamp(previous.a + 1.0, 1.0, 30.0);
    vec3 diffuseFinal = mix(previous.rgb, diffuse, 1.0 / counter);

    outDiffuse = vec4(diffuseFinal, 1.0);
    outDiffusePrevious = vec4(diffuseFinal, counter);
}
