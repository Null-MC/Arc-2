#version 430 core

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outColorPrev;

uniform sampler2D texFinal;
uniform sampler2D texFinalPrev;
uniform sampler2D depthtex1;

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/taa_jitter.glsl"


vec3 encodePalYuv(vec3 rgb) {
    // rgb = RGBToLinear(rgb);

    return vec3(
        dot(rgb, vec3(0.299, 0.587, 0.114)),
        dot(rgb, vec3(-0.14713, -0.28886, 0.436)),
        dot(rgb, vec3(0.615, -0.51499, -0.10001))
    );
}

vec3 decodePalYuv(vec3 yuv) {
    vec3 rgb = vec3(
        dot(yuv, vec3(1.0, 0.0, 1.13983)),
        dot(yuv, vec3(1.0, -0.39465, -0.58060)),
        dot(yuv, vec3(1.0, 2.03211, 0.0))
    );

    // return LinearToRGB(rgb);
    return rgb;
}

vec3 getReprojectedClipPos(const in vec2 texcoord, const in float depthNow, const in vec3 velocity) {
    vec3 clipPos = vec3(texcoord, depthNow) * 2.0 - 1.0;

    vec3 viewPos = unproject(playerProjectionInverse, clipPos);

    vec3 localPos = mul3(playerModelViewInverse, viewPos);

    vec3 localPosPrev = localPos - velocity + (cameraPos - previousCameraPosition);

    vec3 viewPosPrev = mul3(playerPreviousModelView, localPosPrev);

    vec3 clipPosPrev = unproject(playerPreviousProjection, viewPosPrev);

    return clipPosPrev * 0.5 + 0.5;
}

void main() {
    // vec3 colorFinal = ApplyTAA(uv);

    vec2 uv2 = uv;

    uv2 += getJitterOffset(frameCounter);

    float depth = textureLod(depthtex1, uv, 0).r;

    // TODO: add velocity buffer
    vec3 velocity = vec3(0.0); //textureLod(BUFFER_VELOCITY, uv, 0).xyz;
    vec2 uvLast = getReprojectedClipPos(uv, depth, velocity).xy;

    // const float exposureF = exp2(POST_EXPOSURE);

    #ifdef EFFECT_TAA_SHARPEN
        vec4 lastColor = sampleHistoryCatmullRom(uvLast);
    #else
        vec4 lastColor = textureLod(texFinalPrev, uvLast, 0);
    #endif
    // lastColor.rgb *= exposureF;

    vec3 antialiased = lastColor.rgb;
    // float mixRate = min(lastColor.a, 0.5);
    float mixRate = clamp(lastColor.a, 0.02, 1.0);
    // #ifdef EFFECT_TAA_ACCUM
    //     mixRate = 0.0;
    // #endif

    if (saturate(uvLast) != uvLast)
        mixRate = 1.0;
    
    vec3 in0 = textureLod(texFinal, uv, 0).rgb;// * exposureF;
    // return vec4(in0, 1.0);
    // return vec4(lastColor.rgb, 1.0);
    
    antialiased = mix(antialiased * antialiased, in0 * in0, mixRate);
    antialiased = sqrt(antialiased);

    // vec2 viewSize = vec2(viewWidth, viewHeight);
    vec2 pixelSize = 1.0 / screenSize;
    
    vec3 in1 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, 0.0), 0).rgb;// * exposureF;
    vec3 in2 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, 0.0), 0).rgb;// * exposureF;
    vec3 in3 = textureLod(texFinal, uv2 + vec2(0.0, +pixelSize.y), 0).rgb;// * exposureF;
    vec3 in4 = textureLod(texFinal, uv2 + vec2(0.0, -pixelSize.y), 0).rgb;// * exposureF;
    vec3 in5 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, +pixelSize.y), 0).rgb;// * exposureF;
    vec3 in6 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, +pixelSize.y), 0).rgb;// * exposureF;
    vec3 in7 = textureLod(texFinal, uv2 + vec2(+pixelSize.x, -pixelSize.y), 0).rgb;// * exposureF;
    vec3 in8 = textureLod(texFinal, uv2 + vec2(-pixelSize.x, -pixelSize.y), 0).rgb;// * exposureF;
    
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

    minColor = mix(minColor,
       min(min(min(in5, in6), min(in7, in8)), minColor), 0.5);

    maxColor = mix(maxColor,
       max(max(max(in5, in6), max(in7, in8)), maxColor), 0.5);
    
    vec3 preclamping = antialiased;
    vec3 clamped = clamp(antialiased, minColor, maxColor);
    #ifdef EFFECT_TAA_ACCUM
        antialiased = mix(antialiased, clamped, mixRate);
    #else
        antialiased = clamped;
    #endif
    
    mixRate = 1.0 / (1.0 / mixRate + 1.0);
    
    vec3 diff = antialiased - preclamping;
    float clampAmount = dot(diff, diff);
    
    const float weightMax = 1.0 / EFFECT_TAA_MAX_ACCUM;

    mixRate += clampAmount;// * 4.0;
    mixRate = clamp(mixRate, weightMax, 1.0);
    
    antialiased = decodePalYuv(antialiased);
        
    // return vec4(antialiased, mixRate);

    outColor = vec4(antialiased, 1.0);
    outColorPrev = vec4(antialiased, mixRate);
}
