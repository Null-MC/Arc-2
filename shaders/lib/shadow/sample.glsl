//const float ShadowBias[] = float[](
//    0.000012, 0.000024, 0.000064, 0.000256);


float GetShadowDither() {
    #ifndef RENDER_COMPUTE
        #ifdef EFFECT_TAA_ENABLED
            return InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            return InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
    #else
        return 0.0;
    #endif
}

float GetShadowRange(const in int shadowCascade) {
    return -2.0 / ap.celestial.projection[shadowCascade][2][2];
}

float SampleShadow(in vec3 shadowPos, const in int shadowCascade) {
    if (saturate(shadowPos) != shadowPos) return 1.0;

    #ifdef SHADOW_DISTORTION_ENABLED
        shadowPos.xy = shadowPos.xy * 2.0 - 1.0;
        shadowPos = shadowDistort(shadowPos);
        shadowPos.xy = shadowPos.xy * 0.5 + 0.5;
    #endif

    vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
    float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;

    return step(shadowPos.z, depthOpaque);
}

float SampleShadow_PCF(const in vec3 shadowPos, const in int shadowCascade, const in float pixelRadius, const in float sss) {
    if (saturate(shadowPos) != shadowPos) return 1.0;

    float dither = GetShadowDither();

    float zRange = GetShadowRange(shadowCascade);
    float bias_scale = MATERIAL_SSS_DISTANCE / zRange;
    float seed_pos = hash13(shadowPos * 999.0); // TODO

    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    float shadowFinal = 0.0;
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        float sample_dither = sss * hash13(vec3(seed_pos * 999.0, i, ap.time.frames));
        float sample_bias = bias_scale * _pow3(sample_dither);
        //shadowViewPos.z += sssDist;
        
        vec2 pcfDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcfDiskOffset) * pixelRadius;
        vec3 sampleShadowPos = shadowPos + vec3(pixelOffset, sample_bias);

        shadowFinal += SampleShadow(sampleShadowPos, shadowCascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

vec3 SampleShadowColor(in vec3 shadowPos, const in int shadowCascade, out float depthDiff) {
    depthDiff = 0.0;

    if (saturate(shadowPos) != shadowPos) return vec3(1.0);

    #ifdef SHADOW_DISTORTION_ENABLED
        shadowPos.xy = shadowPos.xy * 2.0 - 1.0;
        shadowPos = shadowDistort(shadowPos);
        shadowPos.xy = shadowPos.xy * 0.5 + 0.5;
    #endif

    vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
    float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;

    vec4 shadowSample = vec4(1.0);

    if (shadowPos.z > depthOpaque) shadowSample.rgb = vec3(0.0);
    else {
        float depthTrans = textureLod(shadowMap, shadowCoord, 0).r;

        float zRange = GetShadowRange(shadowCascade);
        depthDiff = (shadowPos.z - depthTrans) * zRange;

        if (shadowPos.z + EPSILON <= depthTrans) shadowSample.rgb = vec3(1.0);
        else {
            shadowSample = textureLod(texShadowColor, shadowCoord, 0);
            shadowSample.rgb = RgbToLinear(shadowSample.rgb);

            float a2 = shadowSample.a*shadowSample.a;
            shadowSample.rgb = mix(shadowSample.rgb, vec3(0.0), a2*a2);
        }
    }

    return shadowSample.rgb;
}

vec3 SampleShadowColor(const in vec3 shadowPos, const in int shadowCascade) {
    float depthDiff;
    return SampleShadowColor(shadowPos, shadowCascade, depthDiff);
}

vec3 SampleShadowColor_PCF(const in vec3 shadowPos, const in int shadowCascade, const in vec2 pixelRadius) {
    if (saturate(shadowPos) != shadowPos) return vec3(1.0);

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
    float zRange = GetShadowRange(shadowCascade);
    float bias = 1.0;//GetShadowBias(shadowCascade);

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

        vec3 sampleShadowPos = shadowPos;
        sampleShadowPos.xy += pixelOffset;

        #ifdef SHADOW_DISTORTION_ENABLED
            sampleShadowPos.xy = sampleShadowPos.xy * 2.0 - 1.0;
            sampleShadowPos = shadowDistort(sampleShadowPos);
            sampleShadowPos.xy = sampleShadowPos.xy * 0.5 + 0.5;
        #endif

        float texDepth = textureLod(shadowMap, vec3(sampleShadowPos.xy, shadowCascade), 0).r;

        float hitDist = max((sampleShadowPos.z - texDepth) * zRange - bias, 0.0);

        avgDist += hitDist;
        blockers++;// += step(0.0, hitDist);
    }

    // return blockers > 0.0 ? avgDist / blockers : -1.0;
    return avgDist / blockers;
}

vec3 SampleShadowColor_PCSS(const in vec3 shadowPos, const in int shadowCascade) {
    vec2 maxPixelRadius = GetPixelRadius(Shadow_MaxPcfSize, shadowCascade);

    #ifdef SHADOW_BLOCKER_TEX
        vec3 sampleShadowPos = shadowPos;

        #ifdef SHADOW_DISTORTION_ENABLED
            sampleShadowPos.xy = sampleShadowPos.xy * 2.0 - 1.0;
            sampleShadowPos = shadowDistort(sampleShadowPos);
            sampleShadowPos.xy = sampleShadowPos.xy * 0.5 + 0.5;
        #endif

        float avg_depth = textureLod(texShadowBlocker, vec3(sampleShadowPos.xy, shadowCascade), 0).r;
        float blockerDistance = max(sampleShadowPos.z - avg_depth, 0.0) * GetShadowRange(shadowCascade);
    #else
        float blockerDistance = ShadowBlockerDistance(shadowPos, shadowCascade, maxPixelRadius);
    #endif

    // if (blockerDistance <= 0.0) {
    //     // WARN: Is this faster or just doubling work?!
    //     return SampleShadowColor(shadowPos, shadowCascade);
    // }

    #ifdef SHADOW_DISTORTION_ENABLED
        float minShadowPixelRadius = 0.0;//fwidth(shadowPos.x)*10.0;// * shadowPixelSize;
    #else
        const float minShadowPixelRadius = 0.5 * shadowPixelSize;
    #endif

    vec2 pixelRadius = GetPixelRadius(blockerDistance / SHADOW_PENUMBRA_SCALE, shadowCascade);
    pixelRadius = clamp(pixelRadius, vec2(minShadowPixelRadius), maxPixelRadius);
    return SampleShadowColor_PCF(shadowPos, shadowCascade, pixelRadius);
}
