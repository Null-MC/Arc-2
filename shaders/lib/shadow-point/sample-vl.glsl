vec3 sample_AllPointLights_VL(const in vec3 localPos) {
    vec3 viewDir = normalize(localPos);
    vec3 blockLighting = vec3(0.0);

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = min(LightBinMap[lightBinIndex].shadowLightCount, LIGHTING_SHADOW_BIN_MAX_COUNT);
    #else
        const uint maxLightCount = POINT_LIGHT_MAX+POINT_LIGHT_MAX1+POINT_LIGHT_MAX2;
    #endif

    uint blockId;
    vec3 lightPos;
    switch (lightLod) {
        case 0:
            blockId = ap.point.block0[lightIndex];
            lightPos = ap.point.pos0[lightIndex].xyz;
            break;
        case 1:
            blockId = ap.point.block1[lightIndex];
            lightPos = ap.point.pos1[lightIndex].xyz;
            break;
        case 2:
            blockId = ap.point.block2[lightIndex];
            lightPos = ap.point.pos2[lightIndex].xyz;
            break;
    }

    for (uint i = 0; i < LIGHTING_SHADOW_MAX_COUNT; i++) {
        if (i >= maxLightCount) break;

        #ifdef LIGHTING_SHADOW_BIN_ENABLED
            uint lightLod   = LightBinMap[lightBinIndex].lightList[i].shadowLod;
            uint lightIndex = LightBinMap[lightBinIndex].lightList[i].shadowIndex;
        #else
            uint lightLod = -1;
            uint lightIndex = i;

            if      (lightIndex < POINT_LIGHT_MAX0) lightLod = 0;
            else if (lightIndex < POINT_LIGHT_MAX0+POINT_LIGHT_MAX1) lightLod = 1;
            else if (lightIndex < POINT_LIGHT_MAX0+POINT_LIGHT_MAX1+POINT_LIGHT_MAX2) lightLod = 2;
        #endif

        uint blockId;
        vec3 lightPos;
        switch (lightLod) {
            case 0:
                blockId = ap.point.block0[lightIndex];
                lightPos = ap.point.pos0[lightIndex].xyz;
                break;
            case 1:
                blockId = ap.point.block1[lightIndex];
                lightPos = ap.point.pos1[lightIndex].xyz;
                break;
            case 2:
                blockId = ap.point.block2[lightIndex];
                lightPos = ap.point.pos2[lightIndex].xyz;
                break;
        }

        #ifndef LIGHTING_SHADOW_BIN_ENABLED
            if (blockId == uint(-1)) continue;
        #endif

        //uint blockId = ap.point.block[lightIndex];
        #ifndef LIGHTING_SHADOW_BIN_ENABLED
            if (blockId == uint(-1)) continue;
        #endif

        float lightRange = iris_getEmission(blockId);
        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        float lightSize = iris_isFullBlock(blockId) ? 1.0 : 0.15;

        vec3 fragToLight = lightPos - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        const float bias = -0.08;
        float lightShadow = sample_PointLight(localPos, lightSize, lightRange, bias, lightIndex, lightLod);

        float VoL = dot(viewDir, sampleDir);
        float phase = saturate(getMiePhase(VoL));

        blockLighting += BLOCK_LUX * lightShadow * phase * lightColor;
    }

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        // sample non-shadow lights
        uint offset = maxLightCount;
        maxLightCount = min(offset + LightBinMap[lightBinIndex].lightCount, LIGHTING_SHADOW_BIN_MAX_COUNT);
        for (uint i = offset; i < LIGHTING_SHADOW_BIN_MAX_COUNT; i++) {
            if (i >= maxLightCount) break;

            vec3 voxelPos = GetLightVoxelPos(LightBinMap[lightBinIndex].lightList[i].voxelIndex) + 0.5;
            uint blockId = SampleVoxelBlock(voxelPos);
            float lightRange = iris_getEmission(blockId);
            vec3 lightColor = iris_getLightColor(blockId).rgb;
            lightColor = RgbToLinear(lightColor);

            vec3 lightLocalPos = voxel_getLocalPosition(voxelPos);
            vec3 fragToLight = lightLocalPos - localPos;
            float sampleDist = length(fragToLight);
            vec3 sampleDir = fragToLight / sampleDist;

            float light_att = GetLightAttenuation(sampleDist, lightRange);

            float VoL = dot(viewDir, sampleDir);
            float phase = saturate(getMiePhase(VoL));
            float lightShadow = phase * light_att;

            blockLighting += BLOCK_LUX * lightShadow * lightColor;
        }
    #endif

    return blockLighting;
}
