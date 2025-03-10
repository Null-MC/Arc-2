mat3 GetTBN(const in vec3 normal, const in vec3 tangent, const in float tangentW) {
    vec3 binormal = normalize(cross(tangent, normal)) * sign(tangentW);
    return mat3(tangent, binormal, normal);
}
