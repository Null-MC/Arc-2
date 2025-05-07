vec3 tonemap_jodieReinhard(vec3 c) {
    // From: https://www.shadertoy.com/view/tdSXzD
    float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tc = c / (c + 1.0);
    return mix(c / (l + 1.0), tc, tc);
}

vec3 tonemap_ACESFit2(const in vec3 color) {
    const mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777);

    const mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602);

    vec3 v = m1 * color;
    vec3 a = v * (v + 0.0245786) - 0.000090537;
    vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
    return saturate(m2 * (a / b));
}

vec3 tonemap_Lottes(const in vec3 color) {
    const vec3 a = vec3(Scene_PostContrastF); // contrast
    const vec3 d = vec3(0.977); // shoulder
    const vec3 hdrMax = vec3(16.0);
    const vec3 midIn = vec3(0.42);
    const vec3 midOut = vec3(0.18);

    const vec3 b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
        
    const vec3 c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);

    return pow(color, a) / (pow(color, a * d) * b + c);
}

vec3 _uchimura(vec3 x, float P, float a, float m, float l, float c, float b) {
    float l0 = ((P - m) * l) / a;
    float L0 = m - m / a;
    float L1 = m + (1.0 - m) / a;
    float S0 = m + l0;
    float S1 = m + a * l0;
    float C2 = (a * P) / (P - S1);
    float CP = -C2 / P;

    vec3 w0 = 1.0 - smoothstep(0.0, m, x);
    vec3 w2 = step(m + l0, x);
    vec3 w1 = 1.0 - w0 - w2;

    vec3 T = m * pow(x / m, vec3(c)) + b;
    vec3 S = P - (P - S1) * exp(CP * (x - S0));
    vec3 L = m + a * (x - m);

    return T * w0 + L * w1 + S * w2;
}

vec3 tonemap_Uchimura(vec3 x) {
    const float P = 1.00;  // max display brightness
    const float a = 1.30;  // contrast
    const float m = 0.22; // linear section start
    const float l = 0.40;  // linear section length
    const float c = 1.56; // black
    const float b = 0.00;  // pedestal

    return _uchimura(x, P, a, m, l, c, b);
}

vec3 tonemap_AgX(vec3 color) {
    // Constants for AgX inset and outset matrices
    const mat3 AgXInsetMatrix = mat3(
        0.856627153315983,  0.137318972929847, 0.11189821299995,
        0.0951212405381588, 0.761241990602591, 0.0767994186031903,
        0.0482516061458583, 0.101439036467562, 0.811302368396859);

    const mat3 AgXOutsetMatrix = mat3(
         1.1271005818144368,   -0.1413297634984383,  -0.14132976349843826,
        -0.11060664309660323,   1.157823702216272,   -0.11060664309660294,
        -0.016493938717834573, -0.016493938717834257, 1.2519364065950405);

    // Constants for AgX exposure range
    const float AgxMinEv = -11.5;
    const float AgxMaxEv = 9.6;

    // Constants for agxAscCdl operation
    const vec3 SLOPE = vec3(0.998);
    const vec3 OFFSET = vec3(0.0);
    const vec3 POWER = vec3(Scene_PostContrastF);
    const float SATURATION = 1.4;

    // 1. agx()
    // Input transform (inset)
    color = AgXInsetMatrix * color;
    color = max(color, 1e-10); // Avoid 0 or negative numbers for log2

    // Log2 space encoding
    color = clamp(log2(color), AgxMinEv, AgxMaxEv);
    color = (color - AgxMinEv) / (AgxMaxEv - AgxMinEv);
    color = saturate(color);

    // Apply sigmoid function approximation
    vec3 x2 = color * color;
    vec3 x4 = x2 * x2;
    color = 15.5 * x4 * x2 - 40.14 * x4 * color + 31.96 * x4 - 6.868 * x2 * color + 0.4298 * x2 + 0.1191 * color - 0.00232;

    // 2. agxAscCdl
    float luma = luminance(color);
    vec3 c = pow(color * SLOPE + OFFSET, POWER);
    color = luma + SATURATION * (c - luma);

    // 3. agxEotf()
    color = AgXOutsetMatrix * color;

    // sRGB IEC 61966-2-1 2.2 Exponent Reference EOTF Display
    color = pow(max(vec3(0.0), color), vec3(2.2));

    return color;
}

vec3 tonemap_Commerce(vec3 color) {
    const float startCompression = 0.8 - 0.04;
    const float desaturation = 0.15;

    float x = minOf(color);
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;

    float peak = maxOf(color);
    if (peak < startCompression) return color;

    float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    color *= newPeak / peak;

    float g = 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(vec3(newPeak), color, g);
}
