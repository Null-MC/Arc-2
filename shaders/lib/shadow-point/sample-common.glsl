#ifdef LIGHTING_SHADOW_PCSS
    float sample_PointLightDepth(const in vec3 sampleDir, const in uint index) {
        vec4 samplePos = vec4(sampleDir, index);

        float depth;
        switch (lod) {
            case 0u:
                depth = texture(pointLight0, samplePos).r;
                break;
            case 1u:
                depth = texture(pointLight1, samplePos).r;
                break;
            case 2u:
                depth = texture(pointLight2, samplePos).r;
                break;
        }

        float ndcDepth = depth * 2.0 - 1.0;
        return 2.0 * pointNearPlane * pointFarPlane / (pointFarPlane + pointNearPlane - ndcDepth * (pointFarPlane - pointNearPlane));
    }
#endif

float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float lightRange, const float bias, const in uint index, const in uint lod) {
    if (sampleDist >= lightRange) return 0.0;

    float linearDepth = sampleDist - bias;
    float ndcDepth = (pointFarPlane + pointNearPlane - 2.0 * pointNearPlane * pointFarPlane / linearDepth) / (pointFarPlane - pointNearPlane);
    float depth = ndcDepth * 0.5 + 0.5;

    vec4 samplePos = vec4(sampleDir, index);

    float result;
    switch (lod) {
        case 0u:
            result = texture(pointLight0Filtered, samplePos, depth).r;
            break;
        case 1u:
            result = texture(pointLight1Filtered, samplePos, depth).r;
            break;
        case 2u:
            result = texture(pointLight2Filtered, samplePos, depth).r;
            break;
    }
    return result;
}

float sample_PointLight(const in vec3 localPos, const in float lightSize, const in float lightRange, const in float bias, const in uint index, const in uint lod) {
    vec3 lightPos = getPointLightPos(lod, index);

    vec3 fragToLight = localPos - lightPos;
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    vec3 absDist = abs(fragToLight);
    float faceDepth = maxOf(absDist);

    #ifdef LIGHTING_SHADOW_PCSS
        const int PointLight_BlockerCount = 5;
        const int PointLight_FilterCount = 6;

        #ifdef RENDER_COMPUTE
            vec2 fragCoord = vec2(0.0);
        #else
            vec2 fragCoord = gl_FragCoord.xy;
        #endif

        float blocker_radius = 0.1 * lightSize;

        float avg_depth = 0.0;
        for (int i = 0; i < PointLight_BlockerCount; i++) {
            vec3 seed = vec3(fragCoord, ap.time.frames + i);
            vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
            //vec3 randomVec = sample_blueNoiseNorm(fragCoord + (i+8)*vec2(27.0, 13.0));
            if (dot(randomVec, sampleDir) < 0.0) randomVec = -randomVec;
            randomVec = mix(sampleDir, randomVec, blocker_radius);

            avg_depth += sample_PointLightDepth(randomVec, index);
        }
        avg_depth /= PointLight_BlockerCount;

        avg_depth = max(avg_depth - 0.5*lightSize, 0.0);

        float face_depth = max(faceDepth - 0.5*lightSize, 0.0);

        float wPenumbra = (face_depth - avg_depth) * lightSize / avg_depth;
        float sample_radius = 0.5 * atan(wPenumbra / face_depth);

        float light_shadow = 0.0;
        for (int i = 0; i < PointLight_FilterCount; i++) {
            vec3 seed = vec3(fragCoord, ap.time.frames + i + 9.0);
            vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
            //vec3 randomVec = sample_blueNoiseNorm(fragCoord + i*vec2(27.0, 13.0));
            if (dot(randomVec, sampleDir) < 0.0) randomVec = -randomVec;
            randomVec = mix(sampleDir, randomVec, sample_radius);

            light_shadow += sample_PointLightShadow(randomVec, faceDepth, lightRange, bias, index, lod);
        }
        light_shadow /= PointLight_FilterCount;
    #else
        float light_shadow = sample_PointLightShadow(sampleDir, faceDepth, lightRange, bias, index, lod);
    #endif

    float light_att = GetLightAttenuation(sampleDist, lightRange);

    return light_shadow * light_att;
}
