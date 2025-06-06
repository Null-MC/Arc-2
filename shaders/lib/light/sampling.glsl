const float ROUGH_MIN = 0.02;


float GetLightAttenuation_Linear(const in vec3 lightVec, const in float lightRange) {
    float lightDistF = length(lightVec) / lightRange;
    return pow5(1.0 - saturate(lightDistF));
}

float GetLightAttenuation_invSq(const in vec3 lightVec, const in float lightRange) {
    float lightDist = length(lightVec);

    return 1.0 / (_pow2(lightDist)+0.01);
}

float GetLightAttenuation(const in vec3 lightVec, const in float lightRange) {
    float lightDist = length(lightVec);

    float linear = 1.0 - saturate(lightDist / lightRange);
    float inv_sq = 1.0 / (_pow2(lightDist)+0.01);
    return min(inv_sq, linear*10.0) * 3.0;
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
