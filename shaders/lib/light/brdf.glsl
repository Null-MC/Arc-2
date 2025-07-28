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

float V_SmithGGXCorrelated(float NdotL, float NdotV, float roughness) {
    float a = roughness * roughness;
    float k = (a + 1.0) * (a + 1.0) / 8.0;
    float G_V = NdotV / (NdotV * (1.0 - k) + k);
    float G_L = NdotL / (NdotL * (1.0 - k) + k);
    return G_V * G_L;
}

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

//float LightingFuncGGX_OPT5(float NoH, float LoH, float F0, float roughness) {
//    float D = g_txGgxDFV.Sample(g_samLinearClamp, vec2(Pow4(NoH), roughness)).x;
//    vec2 FV_helper = g_txGgxDFV.Sample(g_samLinearClamp, vec2(LoH, roughness)).yz;
//
//    float FV = F0*FV_helper.x + FV_helper.y;
//    return D * FV; // * NoL
//}
