void randomize_reflection(inout vec3 reflectRay, const in vec3 normal, const in float roughL) {
    #ifdef EFFECT_TAA_ENABLED
        vec3 seed = vec3(gl_FragCoord.xy, 1.0 + frameCounter);
    #else
        vec3 seed = vec3(gl_FragCoord.xy, 1.0);
    #endif

    vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
    if (dot(randomVec, normal) <= 0.0) randomVec = -randomVec;

    float roughScatterF = 0.25 * (roughL*roughL);
    reflectRay = mix(reflectRay, randomVec, roughScatterF);
    reflectRay = normalize(reflectRay);
}
