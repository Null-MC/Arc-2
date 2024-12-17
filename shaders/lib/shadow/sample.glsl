const float ShadowBias[] = float[](
    0.000012, 0.000024, 0.000064, 0.000256);


float GetShadowDither() {
    #ifdef EFFECT_TAA_ENABLED
        return InterleavedGradientNoiseTime(gl_FragCoord.xy);
    #else
        return InterleavedGradientNoise(gl_FragCoord.xy);
    #endif
}

float SampleShadow(const in vec3 shadowPos, const in int shadowCascade) {
    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return 1.0;

    vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
    float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;

    return step(shadowPos.z - ShadowBias[shadowCascade], depthOpaque);
}

float SampleShadow_PCF(const in vec3 shadowPos, const in int shadowCascade, const in float pixelRadius) {
    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return 1.0;

    float dither = GetShadowDither();

    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    float shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        vec2 pcfDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcfDiskOffset) * pixelRadius;
        vec3 sampleShadowPos = shadowPos + vec3(pixelOffset, 0.0);

        shadowFinal += SampleShadow(sampleShadowPos, shadowCascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

vec3 SampleShadowColor(const in vec3 shadowPos, const in int shadowCascade) {
    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return vec3(1.0);

    vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
    float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;

    vec4 shadowSample = vec4(1.0);

    if (shadowPos.z > depthOpaque) shadowSample.rgb = vec3(0.0);
    else {
        float depthTrans = textureLod(shadowMap, shadowCoord, 0).r;

        if (shadowPos.z + EPSILON <= depthTrans) shadowSample.rgb = vec3(1.0);
        else {
            shadowSample = textureLod(texShadowColor, shadowCoord, 0);
            shadowSample.rgb = RgbToLinear(shadowSample.rgb);
        }
    }

    return shadowSample.rgb;
}

vec3 SampleShadowColor_PCF(const in vec3 shadowPos, const in int shadowCascade, const in vec2 pixelRadius) {
    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return vec3(1.0);

    float dither = GetShadowDither();
    float bias = GetShadowBias(shadowCascade);

    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    // const float pixelRadius = 2.0 / shadowMapResolution;

    vec3 shadowFinal = vec3(0.0);
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        vec2 pcfDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcfDiskOffset) * pixelRadius;
        vec3 sampleShadowPos = shadowPos + vec3(pixelOffset, -bias);

        shadowFinal += SampleShadowColor(sampleShadowPos, shadowCascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

float ShadowBlockerDistance(const in vec3 shadowPos, const in int shadowCascade, const in vec2 pixelRadius) {
    float dither = GetShadowDither();
    float zRange = -2.0 / shadowProjection[shadowCascade][2][2]; //GetShadowRange();
    float bias = GetShadowBias(shadowCascade);

    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    float blockers = 0.0;
    float avgDist = 0.0;
    for (int i = 0; i < SHADOW_PCSS_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCSS_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        vec2 pcssDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcssDiskOffset) * pixelRadius;

        float texDepth = textureLod(solidShadowMap, vec3(shadowPos.xy + pixelOffset, shadowCascade), 0).r;

        float hitDist = max(shadowPos.z - texDepth - bias, 0.0) * zRange;

        avgDist += hitDist;
        blockers++;// += step(0.0, hitDist);
    }

    // return blockers > 0.0 ? avgDist / blockers : -1.0;
    return avgDist / blockers;
}

vec3 SampleShadowColor_PCSS(const in vec3 shadowPos, const in int shadowCascade) {
    vec2 maxPixelRadius = GetPixelRadius(Shadow_MaxPcfSize, shadowCascade);
    float blockerDistance = ShadowBlockerDistance(shadowPos, shadowCascade, 0.5 * maxPixelRadius);

    if (blockerDistance <= 0.0) {
        // WARN: Is this faster or just doubling work?!
        return SampleShadowColor(shadowPos, shadowCascade);
    }

    const float SHADOW_PENUMBRA_SCALE = 24.0;
    const float minShadowPixelRadius = 1.25 * shadowPixelSize;

    vec2 pixelRadius = GetPixelRadius(blockerDistance / SHADOW_PENUMBRA_SCALE, shadowCascade);
    pixelRadius = clamp(pixelRadius, vec2(minShadowPixelRadius), maxPixelRadius);
    return SampleShadowColor_PCF(shadowPos, shadowCascade, pixelRadius);
}
