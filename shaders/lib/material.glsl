vec3 mat_normal_lab(const in vec2 data) {
    vec3 normal = data.xyy * 2.0 - 1.0;
    normal.z = sqrt(max(1.0 - dot(normal.xy, normal.xy), 0.0));
    return normal;
}

vec3 mat_normal_old(const in vec3 data) {
    return normalize(data * 2.0 - 1.0);
}

float mat_emission_lab(const in float data) {
    return data * (255.0/254.0) * step(data, (254.5/255.0));
}

float mat_porosity_lab(const in float data) {
    return data * (255.0/64.0) * step(data, (64.5/255.0));
}

float mat_sss_lab(const in float data) {
    return max(data - (64.0/255.0), 0.0) * (255.0/191.0);
}
