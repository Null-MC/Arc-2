vec3 mat_normal_lab(const in vec2 data) {
    vec2 normal_xy = fma(data.xy, vec2(2.0), vec2(-1.0));
    float normal_z = sqrt(max(1.0 - dot(normal_xy, normal_xy), 0.0));
    return vec3(normal_xy, normal_z);
}

vec3 mat_normal_old(const in vec3 data) {
    return normalize(fma(data, vec3(2.0), vec3(-1.0)));
}

vec3 mat_normal(const in vec3 normalData) {
    #if MATERIAL_FORMAT == MAT_LABPBR
        return mat_normal_lab(normalData.xy);
    #elif MATERIAL_FORMAT == MAT_OLDPBR
        return mat_normal_old(normalData);
    #else
        return vec3(0.0);
    #endif
}

float mat_roughness(const in float data) {
    return 1.0 - data;
}

float mat_emission_lab(const in float data) {
    return fract(data);// * (255.0/254.0);
}

float mat_emission_old(const in float data) {
    return data;
}

float mat_emission(const in vec4 specularData) {
    #if MATERIAL_FORMAT == MAT_LABPBR
        return mat_emission_lab(specularData.a);
    #elif MATERIAL_FORMAT == MAT_OLDPBR
        return mat_emission_old(specularData.b);
    #else
        return 0.0;
    #endif
}

float mat_porosity_lab(const in float data) {
    return data * (255.0/64.0) * step(data, (64.5/255.0));
}

float mat_porosity_old(const in float roughness, const in float f0_metal) {
    float metalInv = 1.0 - saturate(unmix(f0_metal, 0.04, (229.0/255.0)));
    return sqrt(roughness) * metalInv;
}

float mat_porosity(const in float data, const in float roughness, const in float f0_metal) {
    #if MATERIAL_POROSITY_FORMAT == MAT_LABPBR || (MATERIAL_POROSITY_FORMAT == MAT_NONE && MATERIAL_FORMAT == MAT_LABPBR)
        return mat_porosity_lab(data);
    #else
        return mat_porosity_old(roughness, f0_metal);
    #endif
}

float mat_sss_lab(const in float data) {
    return max(data - (64.0/255.0), 0.0) * (255.0/191.0);
}

float mat_metalness_lab(const in float f0_metal) {
    return step((229.5/255.0), f0_metal);
}

float mat_metalness_old(const in float f0_metal) {
    return f0_metal;
}

float mat_metalness(const in float f0_metal) {
    #if MATERIAL_FORMAT == MAT_LABPBR
        return mat_metalness_lab(f0_metal);
    #elif MATERIAL_FORMAT == MAT_OLDPBR
        return mat_metalness_old(f0_metal);
    #else
        return 0.0;
    #endif
}
