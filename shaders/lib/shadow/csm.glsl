void GetShadowProjection(const in vec3 shadowViewPos, const in float padding, out int cascadeIndex, out vec3 shadowPos) {
    float shadowPixel = 1.0 / shadowMapResolution;
    float padding2 = 2.0 * padding;

    for (int i = 0; i < 4; i++) {
        shadowPos = (shadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz;
        cascadeIndex = i;

        if (clamp(shadowPos, -1.0 + padding2, 1.0 - padding2) == shadowPos) break;
    }
}

vec3 GetShadowSamplePos(const in vec3 shadowViewPos, const in float padding, out int shadowCascade) {
    vec3 shadowPos;
    GetShadowProjection(shadowViewPos, padding, shadowCascade, shadowPos);
    return shadowPos * 0.5 + 0.5;
}
