float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float range, const float bias, const in uint index) {
    const float near_plane = 0.05;
    const float far_plane = 16.0;
    //const float bias = 0.08;

    if (sampleDist >= range) return 0.0;

    float linearDepth = sampleDist - bias;
    float ndcDepth = (far_plane + near_plane - 2.0 * near_plane * far_plane / linearDepth) / (far_plane - near_plane);
    float depth = ndcDepth * 0.5 + 0.5;

    return texture(pointLightFiltered, vec4(sampleDir, index), depth).r;
//    float closestDepth = far_plane * near_plane / (sampledReversedZ * (far_plane - near_plane) + near_plane);
//
//    return step(sampleDist - bias, closestDepth);
}

float sample_PointLight(const in vec3 localPos, const in float range, const in float bias, const in uint index) {
    vec3 fragToLight = localPos - ap.point.pos[index].xyz;
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    vec3 absDist = abs(fragToLight);
    float faceDepth = max(max(absDist.x, absDist.y), absDist.z);

    float light_shadow = sample_PointLightShadow(sampleDir, faceDepth, range, bias, index);

    float light_att = GetLightAttenuation_Linear(sampleDist, range);

    return light_shadow * light_att;
}
