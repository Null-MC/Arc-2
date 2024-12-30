mat3 GetTBN(const in vec3 normal, const in vec3 tangent, const in float tangentW) {
    vec3 binormal = normalize(cross(tangent, normal) * tangentW);
    return mat3(tangent, binormal, normal);
}

//mat3 GetViewTBN(const in vec3 viewNormal, const in vec3 viewTangent, const in float tangentW) {
//    vec3 viewBinormal = normalize(cross(viewTangent, viewNormal) * tangentW);
//    return mat3(viewTangent, viewBinormal, viewNormal);
//}
