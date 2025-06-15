float sample_PointLightShadow(const in vec3 sampleDir, const in float sampleDist, const in float range, const in uint index) {
    const float near_plane = 0.05;
    const float far_plane = 16.0;
    const float bias = 0.02;

    if (sampleDist >= range) return 1.0;

    float sampledReversedZ = texture(pointLight, vec4(sampleDir, index)).r;
    float closestDepth = far_plane * near_plane / (sampledReversedZ * (far_plane - near_plane) + near_plane);

    return step(sampleDist - bias, closestDepth);
}

float sample_PointLight(const in vec3 localPos, const in float range, const in uint index) {
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

    #ifdef SHADOW_LIGHT_LISTS
        vec3 voxelPos = voxel_GetBufferPosition(0.02 * localGeoNormal + localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = min(LightBinMap[lightBinIndex].shadowLightCount, RT_MAX_LIGHT_COUNT);
    #else
        const uint maxLightCount = POINT_LIGHT_MAX;
    #endif

    for (uint i = 0u; i < maxLightCount; i++) {
        #ifdef SHADOW_LIGHT_LISTS
            uint lightIndex = LightBinMap[lightBinIndex].lightList[i].shadowIndex;
        #else
            uint lightIndex = i;
        #endif

        uint blockId = ap.point.block[lightIndex];
        float lightRange = iris_getEmission(blockId);
        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        vec3 fragToLight = ap.point.pos[lightIndex].xyz - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        float light_NoL = step(0.0, dot(localGeoNormal, sampleDir));
        float lightShadow = light_NoL * sample_PointLight(localPos, lightRange, lightIndex);

        blockLighting += BLOCK_LUX * lightShadow * lightColor;
    }

    #ifdef SHADOW_LIGHT_LISTS
        // sample non-shadow lights
        uint offset = maxLightCount;
        maxLightCount = min(offset + LightBinMap[lightBinIndex].lightCount, RT_MAX_LIGHT_COUNT);
        for (uint i = offset; i < maxLightCount; i++) {
            vec3 voxelPos = GetLightVoxelPos(LightBinMap[lightBinIndex].lightList[i].voxelIndex) + 0.5;
            uint blockId = SampleVoxelBlock(voxelPos);
            float lightRange = iris_getEmission(blockId);
            vec3 lightColor = iris_getLightColor(blockId).rgb;
            lightColor = RgbToLinear(lightColor);

            vec3 lightLocalPos = voxel_getLocalPosition(voxelPos);
            vec3 fragToLight = lightLocalPos - localPos;
            float sampleDist = length(fragToLight);
            vec3 sampleDir = fragToLight / sampleDist;

            float light_NoL = step(0.0, dot(localGeoNormal, sampleDir));
            float light_att = GetLightAttenuation_Linear(sampleDist, lightRange);
            float lightShadow = light_NoL * light_att;

            blockLighting += BLOCK_LUX * lightShadow * lightColor;
        }
    #endif

    return blockLighting;
}

vec3 sample_AllPointLights_VL(const in vec3 localPos) {
    vec3 viewDir = normalize(localPos);
    vec3 blockLighting = vec3(0.0);

    #ifdef SHADOW_LIGHT_LISTS
        vec3 voxelPos = voxel_GetBufferPosition(localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = min(LightBinMap[lightBinIndex].shadowLightCount, RT_MAX_LIGHT_COUNT);
    #else
        const uint maxLightCount = POINT_LIGHT_MAX;
    #endif

    for (uint i = 0; i < maxLightCount; i++) {
        #ifdef SHADOW_LIGHT_LISTS
            uint lightIndex = LightBinMap[lightBinIndex].lightList[i].shadowIndex;
        #else
            uint lightIndex = i;
        #endif

        uint blockId = ap.point.block[lightIndex];
        float lightRange = iris_getEmission(blockId);
        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        vec3 fragToLight = ap.point.pos[lightIndex].xyz - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        float lightShadow = sample_PointLight(localPos, lightRange, lightIndex);

        float VoL = dot(viewDir, sampleDir);
        float phase = saturate(getMiePhase(VoL));

        blockLighting += BLOCK_LUX * lightShadow * phase * lightColor;
    }

    return blockLighting;
}
