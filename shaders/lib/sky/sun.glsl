float sun(vec3 rayDir, vec3 sunDir) {
    const float sunSolidAngle = SUN_SIZE * (PI/180.0);
    const float minSunCosTheta = cos(sunSolidAngle);

    float cosTheta = dot(rayDir, sunDir);
    return step(minSunCosTheta, cosTheta);
}
