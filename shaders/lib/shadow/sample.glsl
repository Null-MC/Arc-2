const float ShadowBias[] = float[](
    0.000012, 0.000024, 0.000064, 0.000256);


float SampleShadows(const in vec3 shadowPos, const in int shadowCascade) {
    // vec3 shadowPos;
    // int shadowCascade;
    // GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
    // shadowPos = shadowPos * 0.5 + 0.5;

    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return 1.0;

    // #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    // #else
    //     float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    // #endif

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
        float shadowSample = step(shadowPos.z - ShadowBias[shadowCascade], shadowDepth);
        shadowFinal += shadowSample;
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}

vec3 SampleShadowColor(const in vec3 shadowPos, const in int shadowCascade) {
    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return vec3(1.0);

    const float bias = 0.0;

    vec3 shadowCoord = vec3(shadowPos.xy, shadowCascade);
    float depthOpaque = textureLod(solidShadowMap, shadowCoord, 0).r;

    vec4 shadowSample = vec4(1.0);

    if (shadowPos.z - bias > depthOpaque) shadowSample.rgb = vec3(0.0);
    else {
        float depthTrans = textureLod(shadowMap, shadowCoord, 0).r;

        if (shadowPos.z + EPSILON <= depthTrans) shadowSample.rgb = vec3(1.0);
        else {
            shadowSample = textureLod(texShadowColor, shadowCoord, 0);
            shadowSample.rgb = RgbToLinear(shadowSample.rgb);
            
            // float lum = luminance(shadowSample.rgb);
            // if (lum > 0.0) shadowSample.rgb /= lum;

            // shadowSample.rgb = mix(shadowSample.rgb, vec3(0.0), (shadowSample.a*shadowSample.a));
        }
    }

    return shadowSample.rgb;
}

vec3 SampleShadowColor_PCF(const in vec3 shadowPos, const in int shadowCascade) {
    // vec3 shadowPos;
    // int shadowCascade;
    // GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
    // shadowPos = shadowPos * 0.5 + 0.5;

    if (clamp(shadowPos, 0.0, 1.0) != shadowPos) return vec3(1.0);

    // #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
    // #else
    //     float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    // #endif

    float angle = fract(dither) * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

    const float pixelRadius = 2.0 / shadowMapResolution;

    vec3 shadowFinal = vec3(0.0);
    for (int i = 0; i < SHADOW_PCF_SAMPLES; i++) {
        float r = sqrt((i + 0.5) / SHADOW_PCF_SAMPLES);
        float theta = i * GoldenAngle + PHI;
        
        vec2 pcfDiskOffset = r * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * pcfDiskOffset) * pixelRadius;

        vec3 sampleShadowPos = shadowPos;
        sampleShadowPos.xy += pixelOffset;

        shadowFinal += SampleShadowColor(sampleShadowPos, shadowCascade);
    }

    return shadowFinal / SHADOW_PCF_SAMPLES;
}
