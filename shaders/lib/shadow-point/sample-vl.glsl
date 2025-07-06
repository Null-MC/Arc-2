vec3 sample_AllPointLights_VL(const in vec3 localPos, const in bool isFluid) {
    vec3 viewDir = normalize(localPos);
    vec3 blockLighting = vec3(0.0);

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = LightBinMap[lightBinIndex].shadowLightCount;
        maxLightCount = min(maxLightCount, LIGHTING_SHADOW_BIN_MAX_COUNT);
    #else
        const uint maxLightCount = LIGHTING_SHADOW_MAX_COUNT;
    #endif

    for (uint i = 0; i < maxLightCount; i++) {
        #ifdef LIGHTING_SHADOW_BIN_ENABLED
            uint lightIndex = LightBinMap[lightBinIndex].lightList[i].shadowIndex;
        #else
            uint lightIndex = i;
        #endif

        ap_PointLight light = iris_getPointLight(lightIndex);

        #ifndef LIGHTING_SHADOW_BIN_ENABLED
            if (light.block == -1) continue;
        #endif

        float lightRange = iris_getEmission(light.block);
        lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);

        vec3 lightColor = iris_getLightColor(light.block).rgb;
        lightColor = RgbToLinear(lightColor);

        float lightSize = getLightSize(light.block);

        vec3 fragToLight = light.pos - localPos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;

        if (isFluid) {
            const vec3 extinction = (VL_WaterTransmit + VL_WaterScatter) * VL_WaterDensity;
            lightColor *= exp(-sampleDist * extinction);
        }

        const float bias = -0.08;
        float lightShadow = sample_PointLight(-fragToLight, lightSize, lightRange, bias, lightIndex);

        float VoL = dot(viewDir, sampleDir);
        float phase = saturate(getMiePhase(VoL, 0.4));

        blockLighting += BLOCK_LUX * lightShadow * phase * lightColor;
    }

    #if defined(LIGHTING_SHADOW_BIN_ENABLED) && defined(LIGHTING_SHADOW_VOXEL_FILL)
        // sample non-shadow lights
        uint offset = maxLightCount;
        maxLightCount = min(offset + LightBinMap[lightBinIndex].lightCount, LIGHTING_SHADOW_BIN_MAX_COUNT);
        for (uint i = offset; i < LIGHTING_SHADOW_BIN_MAX_COUNT; i++) {
            if (i >= maxLightCount) break;

            vec3 voxelPos = GetLightVoxelPos(LightBinMap[lightBinIndex].lightList[i].voxelIndex) + 0.5;
            uint blockId = SampleVoxelBlock(voxelPos);

            float lightRange = iris_getEmission(blockId);
            lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);

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
