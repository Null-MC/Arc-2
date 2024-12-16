void GetShadowProjection(in vec3 shadowViewPos, out int cascadeIndex, out vec3 shadowPos) {
    float shadowPixel = 1.0 / shadowMapResolution;
    float padding = 4.0 * shadowPixel;

    for (int i = 0; i < 4; i++) {
        shadowPos = (shadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz;
        cascadeIndex = i;

        if (clamp(shadowPos, -1.0 + padding, 1.0 - padding) == shadowPos) break;
    }
}

vec3 GetShadowSamplePos(const in vec3 shadowViewPos, out int shadowCascade) {
    vec3 shadowPos;
    GetShadowProjection(shadowViewPos, shadowCascade, shadowPos);
    return shadowPos * 0.5 + 0.5;
}
