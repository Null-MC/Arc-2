#ifdef LIGHTING_SHADOW_PCSS
    float sample_PointLightDepth(const in vec3 sampleDir, const in uint index) {
        float depth = texture(pointLight, vec4(sampleDir, index)).r;
        //float ndcDepth = depth * 2.0 - 1.0;
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
    float sampleDist = length(fragToLight);
    vec3 sampleDir = fragToLight / sampleDist;

    #ifdef LIGHTING_SHADOW_PCSS
        const int PointLight_BlockerCount = 2;
        const int PointLight_FilterCount = 3;

        #ifdef RENDER_COMPUTE
            vec2 fragCoord = vec2(0.0);
        #else
            vec2 fragCoord = gl_FragCoord.xy;
        #endif

        const float penumbra_scale = 0.16;

        float dist_initial = sample_PointLightDepth(sampleDir, index);

        float wPenumbra = max(sampleDist - dist_initial, 0.0) * lightSize / dist_initial;
        float blocker_radius = penumbra_scale;// * atan(wPenumbra / sampleDist);

        vec3 up = abs(sampleDir.y) > 0.999 ? vec3(0.0,0.0,1.0) : vec3(0.0,1.0,0.0);
        vec3 tangent = normalize(cross(sampleDir, up));
        const float tangentW = 1.0;

        float rot_seed = InterleavedGradientNoiseTime(fragCoord);
        mat3 rot = GetTBN(sampleDir, tangent, tangentW) * rotateZ(rot_seed * TAU);

        float avg_depth = 0.0;
        for (int i = 0; i < PointLight_BlockerCount; i++) {
            vec2 randomVec = sample_blueNoise(fragCoord + i*vec2(27.0, 13.0)).xz;
            randomVec = randomVec * 2.0 - 1.0;

            vec3 sampleVec;
            sampleVec.xy = randomVec * blocker_radius;
            sampleVec.z = sqrt(1.0 - saturate(dot(sampleVec.xy, sampleVec.xy)));
            sampleVec = normalize(sampleVec);
            sampleVec = rot * sampleVec;

            avg_depth += sample_PointLightDepth(sampleVec, index);
        }
        avg_depth /= PointLight_BlockerCount;

        wPenumbra = max(sampleDist - avg_depth, 0.0) * lightSize / avg_depth;
        float sample_radius = penumbra_scale * atan(wPenumbra / sampleDist);

        float light_shadow = 0.0;
        for (int i = 0; i < PointLight_FilterCount; i++) {
            vec2 randomVec = sample_blueNoise(fragCoord + i*vec2(27.0, 13.0)).xz;
            randomVec = randomVec * 2.0 - 1.0;

            vec3 sampleVec;
            sampleVec.xy = randomVec * sample_radius;
            sampleVec.z = sqrt(1.0 - saturate(dot(sampleVec.xy, sampleVec.xy)));
            sampleVec = normalize(sampleVec);
            sampleVec = rot * sampleVec;

            light_shadow += sample_PointLightShadow(sampleVec, sampleDist, lightRange, bias, index);
        }
        light_shadow /= PointLight_FilterCount;
    #else
        float light_shadow = sample_PointLightShadow(sampleDir, sampleDist, lightRange, bias, index);
    #endif

    float light_att = GetLightAttenuation(sampleDist, lightRange);

    return light_shadow * light_att;
}
