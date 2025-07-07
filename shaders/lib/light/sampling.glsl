const float ROUGH_MIN = 0.02;


float GetLightAttenuation_Linear(const in float lightDist, const in float lightRange) {
    float lightDistF = lightDist / lightRange;
    lightDistF = 1.0 - saturate(lightDistF);
    return pow5(lightDistF);
}

float GetLightAttenuation_Linear(const in vec3 lightVec, const in float lightRange) {
    return GetLightAttenuation_Linear(length(lightVec), lightRange);
}

float GetLightAttenuation_invSq(const in float lightDist, const in float lightSize) {
    return 1.0 / (_pow2(lightDist)+lightSize);
}

float GetLightAttenuation(const in float lightDist, const in float lightRange, const in float lightSize) {
    float linear = GetLightAttenuation_Linear(lightDist, lightRange);
    float invSq = GetLightAttenuation_invSq(max(lightDist-lightSize,0.0), lightSize);

    float f = saturate(lightDist / lightRange);
    return mix(invSq, linear, f);
}

float GetLightAttenuation(const in float lightDist, const in float lightRange) {
    return GetLightAttenuation(lightDist, lightRange, 1.0);
}

float GetLightAttenuation(const in vec3 lightVec, const in float lightRange) {
    return GetLightAttenuation(length(lightVec), lightRange);
}

float getLightSize(int blockId) {
    return iris_isFullBlock(blockId) ? 1.0 : 0.15;
}

float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return light_scatter * view_scatter / PI;
}

//float D_GGX(const in float NoH, const in float roughL) {
//    float a2 = roughL * roughL;
//    float f = (NoH * a2 - NoH) * NoH + 1.0;
//    return a2 / (PI * f * f);
//}

float D_GGX(float NoH, float roughL) {
    float a = NoH * roughL;
    float k = roughL / (1.0 - NoH * NoH + a * a);
    return k * k * (1.0 / PI);
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughL) {
    float a2 = roughL * roughL;
    float GGXL = NoV * sqrt((-NoL * a2 + NoL) * NoL + a2);
    float GGXV = NoL * sqrt((-NoV * a2 + NoV) * NoV + a2);
    return 0.5 / (GGXV + GGXL);
}

float V_SmithGGXCorrelatedFast(float NoV, float NoL, float roughL) {
    //float a = roughL;
    float GGXV = NoL * (NoV * (1.0 - roughL) + roughL);
    float GGXL = NoV * (NoL * (1.0 - roughL) + roughL);
    return 0.5 / (GGXV + GGXL);
}

float SampleLightSpecular(const in float NoL, const in float NoH, const in float NoV, const in float roughL) {
    float alpha = max(roughL, ROUGH_MIN);

    float D = D_GGX(NoH, alpha);

    float V = V_SmithGGXCorrelatedFast(NoV, NoL, roughL);

    return NoL * D * clamp(V, 0.0, 100.0);
}
