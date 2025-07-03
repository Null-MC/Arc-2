#ifdef LIGHTING_SHADOW_PCSS
    float sample_PointLightDepth(const in vec3 sampleDir, const in uint index) {
        float depth = texture(pointLight, vec4(sampleDir, index)).r * 2.0 - 1.0;
        //return 2.0 * pointNearPlane * pointFarPlane / (pointFarPlane + pointNearPlane - ndcDepth * (pointFarPlane - pointNearPlane));
        return depth * (pointFarPlane - pointNearPlane) + pointNearPlane;
    }
#endif

float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float lightRange, in float bias, const in uint index) {
    if (sampleDist >= lightRange) return 0.0;

    float depth = (sampleDist - pointNearPlane) / (pointFarPlane - pointNearPlane);
    bias *= depth;
    depth = (sampleDist - bias - pointNearPlane) / (pointFarPlane - pointNearPlane);
    return texture(pointLightFiltered, vec4(sampleDir, index), depth).r;
}

float sample_PointLight(const in vec3 fragToLight, const in float lightSize, const in float lightRange, const in float bias, const in uint index) {
    //vec3 fragToLight = localPos - lightPos;
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    //vec3 absDist = abs(fragToLight);

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

        float face_depth = max(sampleDist - 0.5*lightSize, 0.0);

        float wPenumbra = (face_depth - avg_depth) * lightSize / avg_depth;
        float sample_radius = 0.5 * atan(wPenumbra / face_depth);

        float light_shadow = 0.0;
        for (int i = 0; i < PointLight_FilterCount; i++) {
            vec3 seed = vec3(fragCoord, ap.time.frames + i + 9.0);
            vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
            //vec3 randomVec = sample_blueNoiseNorm(fragCoord + i*vec2(27.0, 13.0));
            if (dot(randomVec, sampleDir) < 0.0) randomVec = -randomVec;
            randomVec = mix(sampleDir, randomVec, sample_radius);

            light_shadow += sample_PointLightShadow(randomVec, sampleDist, lightRange, bias, index);
        }
        light_shadow /= PointLight_FilterCount;
    #else
        float light_shadow = sample_PointLightShadow(sampleDir, sampleDist, lightRange, bias, index);
    #endif

    float light_att = GetLightAttenuation(sampleDist, lightRange);

    return light_shadow * light_att;
}
