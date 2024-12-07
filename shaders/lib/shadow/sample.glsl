const float ShadowBias[] = float[](
    0.000012, 0.000024, 0.000064, 0.000256);


vec3 GetShadowSamplePos(const in vec3 shadowViewPos, out int shadowCascade) {
    vec3 shadowPos;
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
    return shadowPos * 0.5 + 0.5;
}

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
