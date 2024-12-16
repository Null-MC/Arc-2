vec3 GetPatchDistances(const in float distMin, const in float distMax) {
    vec3 distances = vec3(
        gl_in[0].gl_Position.z,
        gl_in[1].gl_Position.z,
        gl_in[2].gl_Position.z);

    //return saturate((abs(distances) - MIN_DISTANCE) / (MATERIAL_DISPLACE_MAX_DIST - MIN_DISTANCE));
    return smoothstep(distMin, distMax, abs(distances));
}

float GetTessellationQuality(const in float distance, const in float maxQuality) {
    return mix(1.0, maxQuality, pow(1.0 - distance, 5.0));
}

void ApplyPatchControl(const in vec3 distance, const in float maxQuality) {
    gl_TessLevelOuter[0] = GetTessellationQuality(maxOf(distance.yz), maxQuality);
    gl_TessLevelOuter[1] = GetTessellationQuality(maxOf(distance.zx), maxQuality);
    gl_TessLevelOuter[2] = GetTessellationQuality(maxOf(distance.xy), maxQuality);

    gl_TessLevelInner[0] = GetTessellationQuality(maxOf(distance), maxQuality);
}
