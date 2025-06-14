float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float range, const in int index) {
    //const float pointLightRange = 16.0;
    const float near_plane = 0.6;
    const float far_plane = 52.0;
    const float bias = 0.02;


    if (sampleDist >= range) return 1.0;

    //vec3 sampleDir = normalize(fragToLight);
    float sampledReversedZ = texture(pointLight, vec4(sampleDir, index)).r;
    float closestDepth = far_plane * near_plane / (sampledReversedZ * (far_plane - near_plane) + near_plane);

    return step(sampleDist - bias, closestDepth);
}

float sample_PointLight(const in vec3 localPos, const in float range, const in int index) {
    vec3 fragToLight = localPos - ap.point.pos[index].xyz;
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    vec3 absDist = abs(fragToLight);
    float faceDepth = max(max(absDist.x, absDist.y), absDist.z);

    float light_shadow = sample_PointLightShadow(sampleDir, faceDepth, range, index);

    float light_att = GetLightAttenuation_Linear(sampleDist, range);

    return light_shadow * light_att;
}
