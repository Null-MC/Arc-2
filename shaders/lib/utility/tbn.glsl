mat3 GetTBN(const in vec3 normal, const in vec3 tangent, const in float tangentW) {
    vec3 binormal = normalize(cross(tangent, normal)) * sign(tangentW);
    return mat3(tangent, binormal, normal);
}

mat3 generate_tbn(vec3 n) {
    mat3 tbn;
    tbn[2] = n;
    if (n.z < -0.9) {
        tbn[0] = vec3(0.0, -1, 0);
        tbn[1] = vec3(-1, 0, 0);
    } else {
        float a = 1.0 / (1.0 + n.z);
        float b = -n.x * n.y * a;
        tbn[0] = vec3(1.0 - n.x * n.x * a, b, -n.x);
        tbn[1] = vec3(b, 1.0 - n.y * n.y * a, -n.y);
    }
    return tbn;
}
