const vec3 ior_n_iron = vec3(2.9114, 2.9497, 2.5845);
const vec3 ior_k_iron = vec3(3.4040, 3.1710, 2.8060);

const vec3 ior_n_gold = vec3(0.18299, 0.42108, 1.3734);
const vec3 ior_k_gold = vec3(3.6123, 2.3459, 1.8135);

const vec3 ior_n_aluminum = vec3(1.3456, 0.96521, 0.61722);
const vec3 ior_k_aluminum = vec3(7.6635, 6.4581, 5.0699);

const vec3 ior_n_chrome = vec3(3.1071, 3.1812, 2.3230);
const vec3 ior_k_chrome = vec3(4.3511, 4.2311, 3.7505);

const vec3 ior_n_copper = vec3(0.27105, 0.67693, 1.3164);
const vec3 ior_k_copper = vec3(3.8090, 2.6248, 2.2981);

const vec3 ior_n_lead = vec3(1.9100, 1.8300, 1.4400);
const vec3 ior_k_lead = vec3(4.1709, 4.1823, 4.1552);

const vec3 ior_n_platinum = vec3(2.3757, 2.0847, 1.8453);
const vec3 ior_k_platinum = vec3(4.3677, 3.7153, 3.0211);

const vec3 ior_n_silver = vec3(0.15943, 0.14512, 0.13547);
const vec3 ior_k_silver = vec3(4.0728, 3.1900, 2.1997);


const vec3 hcm_n[8] = vec3[](
    ior_n_iron,
    ior_n_gold,
    ior_n_aluminum,
    ior_n_chrome,
    ior_n_copper,
    ior_n_lead,
    ior_n_platinum,
    ior_n_silver);

const vec3 hcm_k[8] = vec3[](
    ior_k_iron,
    ior_k_gold,
    ior_k_aluminum,
    ior_k_chrome,
    ior_k_copper,
    ior_k_lead,
    ior_k_platinum,
    ior_k_silver);


void GetHcmFresnel(const in vec3 albedo, const in int hcm, out vec3 n, out vec3 k) {
    if (hcm >= 230 && hcm <= 237) {
        // HCM conductor
        int hcm_i = hcm - 230;
        n = hcm_n[hcm_i];
        k = hcm_k[hcm_i];
    }
    else {
        // albedo-only conductor
        n = vec3(0.0);
        k = vec3(0.0);
    }
}

bool IsMetal(const in float metal_f0) {
    #if MATERIAL_FORMAT == MAT_LABPBR
        return metal_f0 >= (229.5/255.0);
    #else
        return metal_f0 >= 0.5;
    #endif
}

vec3 GetMetalTint(const in vec3 albedo, const in float metal_f0) {
    #if MATERIAL_FORMAT == MAT_LABPBR
        // #ifndef MATERIAL_HCM_ALBEDO_TINT
        //     int hcm = int(metal_f0 * 255.0 + 0.5);
        //     if (hcm < 255) return vec3(1.0);
        // #else
            if (!IsMetal(metal_f0)) return vec3(1.0);
        // #endif

        // return pow(albedo, vec3(HCM_TintGammaInv));
        return albedo;
    #else
        return mix(vec3(1.0), albedo, metal_f0);
    #endif
}

// void ApplyMetalDarkening(inout vec3 diffuse, inout vec3 specular, const in vec3 albedo, const in float metal_f0, const in float roughL) {
//     #if MATERIAL_SPECULAR == SPECULAR_LABPBR
//         float metalF = IsMetal(metal_f0) ? 1.0 : 0.0;
//     #else
//         float metalF = metal_f0;
//     #endif

//     float smoothness = 1.0 - roughL;

//     diffuse *= mix(1.0, MaterialMetalBrightnessF, metalF * smoothness);
//     specular *= GetMetalTint(albedo, metal_f0) * mix(1.0, smoothness, metalF);
// }
