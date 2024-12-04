void GetShadowProjection(in vec3 shadowViewPos, out int cascadeIndex, out vec3 shadowPos) {
    for (int i = 0; i < 4; i++) {
        shadowPos = (shadowProjection[i] * vec4(shadowViewPos, 1.0)).xyz;
        cascadeIndex = i;

        if (clamp(shadowPos, -1.0, 1.0) == shadowPos) break;
    }
}
