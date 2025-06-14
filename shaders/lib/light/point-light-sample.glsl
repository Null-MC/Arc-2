float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float range, const in int index) {
    const float near_plane = 0.6;
    const float far_plane = 52.0;
    const float bias = 0.02;

    if (sampleDist >= range) return 1.0;

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

vec3 sample_AllPointLights(const in vec3 localPos, const in vec3 localGeoNormal) {
    vec3 blockLighting = vec3(0.0);

    for (int i = 0; i < 8; i++) {
        uint blockId = ap.point.block[i];
        float lightRange = iris_getEmission(blockId);
        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        vec3 fragToLight = ap.point.pos[i].xyz - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        float light_NoL = step(0.0, dot(localGeoNormal, sampleDir));
        float lightShadow = light_NoL * sample_PointLight(localPos, lightRange, i);

        blockLighting += BLOCK_LUX * lightShadow * lightColor;
    }

    return blockLighting;
}

vec3 sample_AllPointLights_VL(const in vec3 localPos) {
    vec3 viewDir = normalize(localPos);
    vec3 blockLighting = vec3(0.0);

    for (int i = 0; i < 8; i++) {
        uint blockId = ap.point.block[i];
        float lightRange = iris_getEmission(blockId);
        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        vec3 fragToLight = ap.point.pos[i].xyz - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        float lightShadow = sample_PointLight(localPos, lightRange, i);

        float VoL = dot(viewDir, sampleDir);
        float phase = saturate(HG(VoL, 0.8));

        blockLighting += BLOCK_LUX * lightShadow * phase * lightColor;
    }

    return blockLighting;
}
