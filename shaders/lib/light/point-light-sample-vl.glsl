vec3 sample_AllPointLights_VL(const in vec3 localPos) {
    vec3 viewDir = normalize(localPos);
    vec3 blockLighting = vec3(0.0);

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = min(LightBinMap[lightBinIndex].shadowLightCount, LIGHTING_SHADOW_MAX_COUNT);
    #else
        const uint maxLightCount = POINT_LIGHT_MAX;
    #endif

    for (uint i = 0; i < maxLightCount; i++) {
        #ifdef LIGHTING_SHADOW_BIN_ENABLED
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

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        // sample non-shadow lights
        uint offset = maxLightCount;
        maxLightCount = min(offset + LightBinMap[lightBinIndex].lightCount, LIGHTING_SHADOW_MAX_COUNT);
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

            float light_att = GetLightAttenuation_Linear(sampleDist, lightRange);

            float VoL = dot(viewDir, sampleDir);
            float phase = saturate(getMiePhase(VoL));
            float lightShadow = phase * light_att;

            blockLighting += BLOCK_LUX * lightShadow * lightColor;
        }
    #endif

    return blockLighting;
}
