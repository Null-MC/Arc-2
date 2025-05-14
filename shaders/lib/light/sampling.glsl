const float ROUGH_MIN = 0.02;

// xy: diffuse, specular
float GetLightAttenuation(const in vec3 lightVec, const in float lightRange, const in float A, const in float R) {
    float lightDist = length(lightVec);
//    float lightAtt = 1.0 - saturate(lightDist / lightRange);
//    return vec2(pow(lightAtt, 5), lightAtt*lightAtt);

    //return pow(saturate(1.0 - pow(lightDist/lightRange, 4)), 2) / (_pow2(lightDist) + 1.0);

    float d_r = lightDist / R;
    return A / (1.0 + _pow2(d_r));
}

float GetLightAttenuation(const in vec3 lightVec, const in float lightRange) {
    return GetLightAttenuation(lightVec, lightRange, 100.0, 0.2);
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
