const float ROUGH_MIN = 0.02;


float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return light_scatter * view_scatter / PI;
}

float D_GGX(const in float NoH, const in float roughL) {
    float a2 = roughL * roughL;
    float f = (NoH * a2 - NoH) * NoH + 1.0;
    return a2 / (PI * f * f);
}

//float D_GGX(float NoH, float roughL) {
//    float a = NoH * roughL;
//    float k = roughL / (1.0 - NoH * NoH + a * a);
//    return k * k * (1.0 / PI);
//}

//float V_SmithGGXCorrelated(float NoV, float NoL, float roughL) {
//    float a2 = roughL * roughL;
//    float GGXL = NoV * sqrt((-NoL * a2 + NoL) * NoL + a2);
//    float GGXV = NoL * sqrt((-NoV * a2 + NoV) * NoV + a2);
//    return 0.5 / (GGXV + GGXL);
//}
//
//float V_SmithGGXCorrelatedFast(float NoV, float NoL, float roughL) {
//    //float a = roughL;
//    float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
//    float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
//    return 0.5 / (GGXV + GGXL);
//}

float V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness) {
    float a = roughness * roughness;
    float k = (a + 1.0) * (a + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

//vec3 CookTorranceSpecular(vec3 albedo, float f0_metal, float roughL, vec3 normal, vec3 lightDir, vec3 viewDir, bool isWet) {
//    vec3 halfDir = normalize(lightDir + viewDir);
//    float NdotL = saturate(dot(normal, lightDir));
//    float NdotV = saturate(dot(normal, viewDir));
//    float NdotH = saturate(dot(normal, halfDir));
//    float VoH = saturate(dot(viewDir, halfDir));
//
//    float D = D_GGX(NdotH, roughL);
//    float G = V_SmithGGXCorrelated(NdotL, NdotV, roughL);
//    //float F = SchlickFresnel(albedo, VoH);
//    vec3 F = material_fresnel(albedo, f0_metal, roughL, VoH, isWet);
//
//    vec3 numerator = D * G * F;
//    float denominator = 4.0 * NdotL * NdotV + 0.0001; // Add a small epsilon to prevent division by zero
//    return numerator / denominator;
//}

float SampleLightSpecular(float NoL, float NoH, float NoV, float F_VoH, float roughL) {
    float D = D_GGX(NoH, roughL);
    float G = V_SmithGGXCorrelated(NoL, NoV, roughL);

    float numerator = D * G * F_VoH;
    float denominator = 4.0 * NoL * NoV + 0.0001;
    return saturate(numerator / denominator);
}

vec3 SampleLightSpecular(float NoL, float NoH, float NoV, vec3 F_VoH, float roughL) {
    float D = D_GGX(NoH, roughL);
    float G = V_SmithGGXCorrelated(NoL, NoV, roughL);

    vec3 numerator = D * G * F_VoH;
    float denominator = 4.0 * NoL * NoV + 0.0001;
    return saturate(numerator / denominator);
}

//float SampleLightSpecular(const in float NoL, const in float NoH, const in float NoV, const in float roughL) {
//    float alpha = max(roughL, ROUGH_MIN);
//
//    float D = D_GGX(NoH, alpha);
//
//    float V = V_SmithGGXCorrelated(NoV, NoL, roughL);
//
//    return NoL * D * clamp(V, 0.0, 100.0);
//}
