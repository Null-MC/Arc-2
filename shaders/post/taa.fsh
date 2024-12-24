#version 430 core

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outColorPrev;

in vec2 uv;

uniform sampler2D texFinal;
uniform sampler2D texFinalPrevious;
uniform sampler2D solidDepthTex;

#include "/lib/common.glsl"
#include "/lib/catmull_rom.glsl"
#include "/lib/taa_jitter.glsl"


// const int EFFECT_TAA_MAX_ACCUM = 16;

vec3 encodePalYuv(vec3 rgb) {
    const mat3 m = mat3(
        vec3(0.29900, -0.14713,  0.61500),
        vec3(0.58700, -0.28886, -0.51499),
        vec3(0.11400,  0.43600, -0.10001));

    return m * rgb;
}

vec3 decodePalYuv(vec3 yuv) {
    const mat3 m = mat3(
        vec3(1.00000,  1.00000, 1.00000),
        vec3(0.00000, -0.39465, 2.03211),
        vec3(1.13983, -0.58060, 0.00000));

    return m * yuv;
}

vec3 getReprojectedClipPos(const in vec2 texcoord, const in float depthNow, const in vec3 velocity) {
    vec3 clipPos = vec3(texcoord, depthNow) * 2.0 - 1.0;

    // jitter(clipPos.xy);

    vec3 viewPos = unproject(playerProjectionInverse, clipPos);

    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localPosPrev = localPos - velocity + (cameraPos - lastCameraPos);

    vec3 viewPosPrev = mul3(lastPlayerModelView, localPosPrev);

    vec3 clipPosPrev = unproject(lastPlayerProjection, viewPosPrev);

    // unjitter(clipPos);

    return clipPosPrev * 0.5 + 0.5;
}

void main() {
    vec2 uv2 = uv;

    // uv2 += getJitterOffset(frameCounter);

    float depth = textureLod(solidDepthTex, uv, 0).r;

    // TODO: add velocity buffer
    vec3 velocity = vec3(0.0); //textureLod(BUFFER_VELOCITY, uv, 0).xyz;
    vec2 uvLast = getReprojectedClipPos(uv, depth, velocity).xy;

    // #ifdef EFFECT_TAA_SHARPEN
        vec4 lastColor = sampleHistoryCatmullRom(texFinalPrevious, uvLast);
    // #else
    //     vec4 lastColor = textureLod(texFinalPrevious, uvLast, 0);
    // #endif

    vec3 antialiased = lastColor.rgb;
    // float mixRate = min(lastColor.a, 0.5);
    float mixRate = clamp(lastColor.a, 0.02, 1.0);
    // #ifdef EFFECT_TAA_ACCUM
    //     mixRate = 0.0;
    // #endif

    // mixRate = 0.0; // WARN: FOR TESTING

    if (clamp(uvLast, 0.0, 1.0) != uvLast)
        mixRate = 1.0;
    
    vec3 in0 = textureLod(texFinal, uv, 0).rgb;

    antialiased = mix(antialiased * antialiased, in0 * in0, mixRate);
    antialiased = sqrt(antialiased);

    vec2 pixelSize = 1.0 / screenSize;
    
    vec3 in1 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, 0.0), 0).rgb;
    vec3 in2 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, 0.0), 0).rgb;
    vec3 in3 = textureLod(texFinal, uv2 + vec2(0.0, +pixelSize.y), 0).rgb;
    vec3 in4 = textureLod(texFinal, uv2 + vec2(0.0, -pixelSize.y), 0).rgb;
    vec3 in5 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, +pixelSize.y), 0).rgb;
    vec3 in6 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, +pixelSize.y), 0).rgb;
    vec3 in7 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, -pixelSize.y), 0).rgb;
    vec3 in8 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, -pixelSize.y), 0).rgb;
    
    antialiased = encodePalYuv(antialiased);
    in0 = encodePalYuv(in0);
    in1 = encodePalYuv(in1);
    in2 = encodePalYuv(in2);
    in3 = encodePalYuv(in3);
    in4 = encodePalYuv(in4);
    in5 = encodePalYuv(in5);
    in6 = encodePalYuv(in6);
    in7 = encodePalYuv(in7);
    in8 = encodePalYuv(in8);
    
    vec3 minColor = min(min(min(in0, in1), min(in2, in3)), in4);
    vec3 maxColor = max(max(max(in0, in1), max(in2, in3)), in4);

    // minColor = mix(minColor,
    //    min(min(min(in5, in6), min(in7, in8)), minColor), 0.5);

    // maxColor = mix(maxColor,
    //    max(max(max(in5, in6), max(in7, in8)), maxColor), 0.5);

    minColor = min(min(min(in5, in6), min(in7, in8)), minColor);
    maxColor = max(max(max(in5, in6), max(in7, in8)), maxColor);
    
    vec3 preclamping = antialiased;
    vec3 clamped = clamp(antialiased, minColor, maxColor);
    // #ifdef EFFECT_TAA_ACCUM
    //     antialiased = mix(antialiased, clamped, mixRate);
    // #else
        antialiased = clamped;
    // #endif
    
    mixRate = 1.0 / (1.0 / mixRate + 1.0);
    
    vec3 diff = antialiased - preclamping;
    float clampAmount = dot(diff, diff);
    
    const float weightMax = 0.02;//1.0 / EFFECT_TAA_MAX_ACCUM;

    mixRate += clampAmount * 0.02;
    mixRate = clamp(mixRate, weightMax, 1.0);
    
    antialiased = decodePalYuv(antialiased);
    
    outColor = vec4(antialiased, 1.0);
    outColorPrev = vec4(antialiased, mixRate);
}
