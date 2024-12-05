float skyDisc(const in vec3 rayDir, const in vec3 lightDir, const in float solidAngle) {
    float minCosTheta = cos(solidAngle);
    float cosTheta = dot(rayDir, lightDir);
    return step(minCosTheta, cosTheta);
}

float sun(vec3 rayDir, vec3 sunDir) {
    const float solidAngle = SUN_SIZE * (PI/180.0);
    // const float minCosTheta = cos(solidAngle);

    return skyDisc(rayDir, sunDir, solidAngle);
}

float moon(vec3 rayDir, vec3 moonDir) {
    const float solidAngle = MOON_SIZE * (PI/180.0);
    // const float minCosTheta = cos(solidAngle);

    return skyDisc(rayDir, moonDir, solidAngle);
}
