const float pointNearPlane = 0.05;
const float pointFarPlane = 16.0;


#ifdef LIGHTING_SHADOW_PCSS
    float sample_PointLightDepth(const in vec3 sampleDir, const in uint index) {
        float ndcDepth = texture(pointLight, vec4(sampleDir, index)).r * 2.0 - 1.0;
        return 2.0 * pointNearPlane * pointFarPlane / (pointFarPlane + pointNearPlane - ndcDepth * (pointFarPlane - pointNearPlane));
    }
#endif

float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float range, const float bias, const in uint index) {
    if (sampleDist >= range) return 0.0;

    float linearDepth = sampleDist - bias;
    float ndcDepth = (pointFarPlane + pointNearPlane - 2.0 * pointNearPlane * pointFarPlane / linearDepth) / (pointFarPlane - pointNearPlane);
    float depth = ndcDepth * 0.5 + 0.5;

    return texture(pointLightFiltered, vec4(sampleDir, index), depth).r;
}

float sample_PointLight(const in vec3 localPos, const in float range, const in float bias, const in uint index) {
    vec3 fragToLight = localPos - ap.point.pos[index].xyz;
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    vec3 absDist = abs(fragToLight);
    float faceDepth = maxOf(absDist);

    #ifdef LIGHTING_SHADOW_PCSS
        const int PointLight_BlockerCount = 3;
        const int PointLight_FilterCount = 3;
        const float blocker_radius = 0.04;

        float avg_depth = 0.0;
        for (int i = 0; i < PointLight_BlockerCount; i++) {
            vec3 seed = vec3(gl_FragCoord.xy, ap.time.frames + i);
            vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
            if (dot(randomVec, sampleDir) < 0.0) randomVec = -randomVec;
            randomVec = mix(sampleDir, randomVec, blocker_radius);

            avg_depth += sample_PointLightDepth(randomVec, index);
        }
        avg_depth /= PointLight_BlockerCount;

        // TODO: base sample radius on avg blocker radius
        float diffF = saturate(abs(faceDepth - avg_depth) * 0.25);
        float sample_radius = diffF * blocker_radius;

        float light_shadow = 0.0;
        for (int i = 0; i < PointLight_FilterCount; i++) {
            vec3 seed = vec3(gl_FragCoord.xy, ap.time.frames + i + 9.0);
            vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
            if (dot(randomVec, sampleDir) < 0.0) randomVec = -randomVec;
            randomVec = mix(sampleDir, randomVec, sample_radius);

            light_shadow += sample_PointLightShadow(randomVec, faceDepth, range, bias, index);
        }
        light_shadow /= PointLight_FilterCount;
    #else
        float light_shadow = sample_PointLightShadow(sampleDir, faceDepth, range, bias, index);
    #endif

    float light_att = GetLightAttenuation_Linear(sampleDist, range);

    return light_shadow * light_att;
}
