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

//vec3 GetAreaLightDir(const in vec3 sampleDir, const in vec3 lightDir, const in float lightDist, const in float lightSize) {
//    vec3 L = lightDir * lightDist;
//    vec3 centerToRay = dot(L, sampleDir) * sampleDir - L;
//    vec3 closestPoint = centerToRay * saturate(lightSize / length(centerToRay)) + L;
//    return normalize(closestPoint);
//}

vec3 GetAreaLightDir(const in vec3 reflectNormal, const in vec3 viewDir, const in vec3 lightDir, const in float lightDist, const in float lightSize) {
    vec3 r = reflect(viewDir, reflectNormal);
    vec3 L = lightDir * lightDist;
    vec3 centerToRay = dot(L, r) * r - L;
    vec3 closestPoint = centerToRay * saturate(lightSize / length(centerToRay)) + L;
    return normalize(closestPoint);
}
