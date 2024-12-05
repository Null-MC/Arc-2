const float sunSolidAngle  = SUN_SIZE * (PI/180.0);
const float moonSolidAngle = MOON_SIZE * (PI/180.0);


float skyDisc(const in vec3 rayDir, const in vec3 lightDir, const in float solidAngle) {
    float minCosTheta = cos(solidAngle);
    float cosTheta = dot(rayDir, lightDir);
    return step(minCosTheta, cosTheta);
}

float skySphere(const in vec3 rayDir, const in vec3 lightDir, const in float solidAngle) {
    float minCosTheta = cos(solidAngle);
    float cosTheta = dot(rayDir, lightDir);
    return clamp((cosTheta - minCosTheta) / (1.0 - minCosTheta), 0.0, 1.0);
}

float sun(vec3 rayDir, vec3 sunDir) {
    // const float minCosTheta = cos(sunSolidAngle);
    return skySphere(rayDir, sunDir, sunSolidAngle);
}

float moon(vec3 rayDir, vec3 moonDir) {
    // const float minCosTheta = cos(moonSolidAngle);
    return skySphere(rayDir, moonDir, moonSolidAngle);
}
