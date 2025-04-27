vec3 F0ToIor(const in vec3 f0, const in vec3 medium) {
    vec3 sqrt_f0 = sqrt(max(f0, EPSILON));
    return (medium + sqrt_f0) / max(medium - sqrt_f0, EPSILON);
}

float F0ToIor(const in float f0, const in float medium) {
    float sqrt_f0 = sqrt(max(f0, EPSILON));
    return (medium + sqrt_f0) / max(medium - sqrt_f0, EPSILON);
}

vec3 IorToF0(const in vec3 ior, const in vec3 medium) {
    vec3 t = (ior - medium) / (ior + medium);
    return t*t;
}

float IorToF0(const in float ior, const in float medium) {
    float t = (ior - medium) / (ior + medium);
    return t*t;
}

float F_schlick(const in float cos_theta, const in float f0, const in float f90) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (f90 - f0) * pow(invCosTheta, 5.0);
}

float F_schlickRough(const in float cos_theta, const in float f0, const in float rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(1.0 - rough, f0) - f0) * pow(invCosTheta, 5.0);
}

vec3 F_schlickRough(const in float cos_theta, const in vec3 f0, const in float rough) {
    float invCosTheta = saturate(1.0 - cos_theta);
    return f0 + (max(vec3(1.0 - rough), f0) - f0) * pow(invCosTheta, 5.0);
}

vec3 ComplexFresnel(const in vec3 n, const in vec3 k, const in float c) {
    vec3 nn = n*n;
    vec3 kk = k*k;
    float cc = c*c;

    vec3 nc2 = 2.0 * n*c;
    vec3 nn_kk = nn + kk;

    vec3 rs_num = nn_kk - nc2 + cc;
    vec3 rs_den = nn_kk + nc2 + cc;
    vec3 rs = rs_num / rs_den;
    
    vec3 rp_num = nn_kk*cc - nc2 + 1.0;
    vec3 rp_den = nn_kk*cc + nc2 + 1.0;
    vec3 rp = rp_num / rp_den;
    
    return saturate(0.5 * (rs + rp));
}
