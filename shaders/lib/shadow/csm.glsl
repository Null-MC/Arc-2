vec2 GetPixelRadius(const in float blockRadius, const in int cascade) {
    vec2 cascadeSize = 2.0 / vec2(ap.celestial.projection[cascade][0].x, ap.celestial.projection[cascade][1].y);
    // vec2 cascadeSize = shadowProjectionSize[cascade];

    // return vec2(8.0 * shadowPixelSize);
    return blockRadius * (shadowMapResolution / cascadeSize) * shadowPixelSize;
    // return (blockRadius / cascadeSize);// * shadowPixelSize;
}

float GetShadowBias(const in int shadowCascade) {
    const float cascade_bias[] = {0.02, 0.04, 0.16, 0.2};

    float zRange = -2.0 / ap.celestial.projection[shadowCascade][2].z; //GetShadowRange();

    return cascade_bias[shadowCascade] / zRange;
}

void GetShadowProjection(const in vec3 shadowViewPos, const in float padding, out int cascadeIndex, out vec3 shadowPos) {
    float shadowPixel = 1.0 / shadowMapResolution;
    // float padding2 = 2.0 * padding;

    for (int i = 0; i < 4; i++) {
        shadowPos = (ap.celestial.projection[i] * vec4(shadowViewPos, 1.0)).xyz;
        cascadeIndex = i;

        vec3 padding2 = vec3(2.0 * GetPixelRadius(padding, i), 0.0);
        if (clamp(shadowPos, -1.0 + padding2, 1.0 - padding2) == shadowPos) break;
    }
}

vec3 GetShadowSamplePos(const in vec3 shadowViewPos, const in float padding, out int shadowCascade) {
    vec3 shadowPos;
    GetShadowProjection(shadowViewPos, padding, shadowCascade, shadowPos);
    return shadowPos * 0.5 + 0.5;
}
