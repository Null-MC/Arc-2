const float ROUGH_MIN = 0.02;

// xy: diffuse, specular
vec2 GetLightAttenuation(const in vec3 lightVec, const in float lightRange) {
    float lightDist = length(lightVec);
    float lightAtt = 1.0 - saturate(lightDist / lightRange);
    return vec2(pow(lightAtt, 5), lightAtt*lightAtt);
}

// float GetLightNoL(const in float geoNoL, const in vec3 texNormal, const in vec3 lightDir) {
//     float NoL = 1.0;

//     float texNoL = geoNoL;
//     if (!all(lessThan(abs(texNormal), EPSILON3)))
//         texNoL = dot(texNormal, lightDir);

//     NoL = max(geoNoL, 0.0);

//     if (!all(lessThan(abs(texNormal), EPSILON3))) {
//         NoL = max(texNoL, 0.0) * step(0.0, geoNoL);
//     }

//     return saturate(NoL);
// }

float SampleLightDiffuse(const in float NoV, const in float NoL, const in float LoH, const in float roughL) {
    float f90 = 0.5 + 2.0*roughL * (LoH*LoH);
    float light_scatter = F_schlick(NoL, 1.0, f90);
    float view_scatter = F_schlick(NoV, 1.0, f90);
    return light_scatter * view_scatter;
}

float G1V(const in float NoV, const in float k) {
    return 1.0 / (NoV * (1.0 - k) + k);
}

vec3 SampleLightSpecular(const in float NoL, const in float NoH, const in float LoH, const in vec3 F, const in float roughL) {
    float alpha = max(roughL, ROUGH_MIN);

    // D
    float alpha2 = alpha*alpha;
    float denom = (NoH*NoH) * (alpha2 - 1.0) + 1.0;
    float D = alpha2 / (PI * (denom*denom));

    // V
    float k = alpha / 2.0;
    float k2 = k*k;
    float V = 1.0 / ((LoH*LoH) * (1.0 - k2) + k2);

    return clamp((NoL * D * V) * F, 0.0, 10.0);
}
