const float ROUGH_MIN = 0.02;


float GetLightAttenuation_Linear(const in float lightDist, const in float lightRange) {
    float lightDistF = lightDist / lightRange;
    return pow5(1.0 - saturate(lightDistF));
    //return 1.0 - saturate(lightDistF);
}

float GetLightAttenuation_Linear(const in vec3 lightVec, const in float lightRange) {
    return GetLightAttenuation_Linear(length(lightVec), lightRange);
}

float GetLightAttenuation_invSq(const in float lightDist) {
    return 1.0 / (_pow2(lightDist)+1.0);
}

float GetLightAttenuation(const in float lightDist, const in float lightRange) {
    //return saturate(1.0 - _pow2(lightDist) / _pow2(lightRange));

    return GetLightAttenuation_Linear(lightDist, lightRange);

//    float linear = GetLightAttenuation_Linear(lightDist, lightRange);
//    float inv_sq = GetLightAttenuation_invSq(lightDist);
//    return min(inv_sq, linear);
}

float GetLightAttenuation(const in vec3 lightVec, const in float lightRange) {
    return GetLightAttenuation(length(lightVec), lightRange);
}

float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return light_scatter * view_scatter;
}

float G1V(const in float NoV, const in float k) {
    return 1.0 / (NoV * (1.0 - k) + k);
}

float SampleLightSpecular(const in float NoL, const in float NoH, const in float LoH, const in float roughL) {
    float alpha = max(roughL, ROUGH_MIN);

    // D
    float alpha2 = alpha*alpha;
    float denom = (NoH*NoH) * (alpha2 - 1.0) + 1.0;
    float D = alpha2 / (PI * (denom*denom));

    // V
    float k = alpha / 2.0;
    float k2 = k*k;
    float V = 1.0 / ((LoH*LoH) * (1.0 - k2) + k2);

    return clamp((NoL * D * V), 0.0, 100.0);
}
