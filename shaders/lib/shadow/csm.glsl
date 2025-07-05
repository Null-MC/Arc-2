vec2 GetPixelRadius(const in float blockRadius, const in int cascade) {
    vec2 cascadeSize = 2.0 / vec2(ap.celestial.projection[cascade][0].x, ap.celestial.projection[cascade][1].y);
    // vec2 cascadeSize = shadowProjectionSize[cascade];

    // return vec2(8.0 * shadowPixelSize);
    return blockRadius * (shadowMapResolution / cascadeSize) * shadowPixelSize;
    // return (blockRadius / cascadeSize);// * shadowPixelSize;
}

float GetShadowBias(const in int shadowCascade) {
    const float cascade_bias[] = {0.04, 0.08, 0.16, 0.2, 0.3, 0.4};

    float zRange = -2.0 / ap.celestial.projection[shadowCascade][2].z; //GetShadowRange();

    return cascade_bias[shadowCascade] / zRange;
}

void GetShadowProjection(const in vec3 shadowViewPos, const in float blockPadding, out int cascadeIndex, out vec3 shadowPos) {
    //float shadowPixel = 1.0 / shadowMapResolution;
    float blockPadding2 = 2.0 * blockPadding;

    cascadeIndex = -1;
    for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
        shadowPos = mul3(ap.celestial.projection[i], shadowViewPos).xyz;

        //vec3 _padding = vec3(2.0 * GetPixelRadius(blockPadding, i), 0.0);
        vec2 cascadeSize = vec2(ap.celestial.projection[i][0].x, ap.celestial.projection[i][1].y);
        vec3 cascadePadding = vec3(blockPadding2 * cascadeSize, 0.0);

        if (clamp(shadowPos, -1.0 + cascadePadding, 1.0 - cascadePadding) == shadowPos) {
            cascadeIndex = i;
            break;
        }
    }
}

vec3 GetShadowSamplePos(const in vec3 shadowViewPos, const in float padding, out int shadowCascade) {
    vec3 shadowPos;
    GetShadowProjection(shadowViewPos, padding, shadowCascade, shadowPos);
    return shadowPos * 0.5 + 0.5;
}
