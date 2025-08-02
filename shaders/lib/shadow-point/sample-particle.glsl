vec3 sample_AllPointLights_particle(const in vec3 localPos) {
    const float offsetBias = 0.8;

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = LightBinMap[lightBinIndex].lightCount;
        maxLightCount = clamp(maxLightCount, 0u, LIGHTING_SHADOW_BIN_MAX_COUNT);
    #else
        const uint maxLightCount = LIGHTING_SHADOW_MAX_COUNT;
    #endif

    vec3 lighting = vec3(0.0);

    for (uint i = 0u; i < maxLightCount; i++) {
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

        vec3 fragToLight = localPos - light.pos;

        if (dot(fragToLight, fragToLight) >= lightRange*lightRange) continue;

        vec3 lightColor = iris_getLightColor(light.block).rgb;
        bool lightFlicker = iris_hasTag(light.block, TAG_LIGHT_FLICKER);
        float lightSize = getLightSize(light.block);

        lightColor = RgbToLinear(lightColor);

        float lightShadow = 1.0;
        #ifdef LIGHT_FLICKERING
            if (lightFlicker) {
                float flicker = GetLightFlicker(light.pos);

                lightShadow *= flicker;
                //lightRange *= flicker;
            }
        #endif

        lightShadow *= sample_PointLight(fragToLight, lightSize, lightRange, offsetBias, lightIndex);

        lighting += lightShadow * lightColor;
    }

//    #if defined(LIGHTING_SHADOW_BIN_ENABLED) && defined(LIGHTING_SHADOW_VOXEL_FILL)
//        // sample non-shadow lights
//        uint offset = maxLightCount;
//        maxLightCount = offset + LightBinMap[lightBinIndex].lightCount;
//        for (uint i = offset; i < LIGHTING_SHADOW_BIN_MAX_COUNT; i++) {
//            if (i >= maxLightCount) break;
//
//            vec3 voxelPos = GetLightVoxelPos(LightBinMap[lightBinIndex].lightList[i].voxelIndex) + 0.5;
//            uint blockId = SampleVoxelBlock(voxelPos);
//
//            float lightRange = iris_getEmission(blockId);
//            lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);
//
//            vec3 lightColor = iris_getLightColor(blockId).rgb;
//            lightColor = RgbToLinear(lightColor);
//
//            vec3 lightLocalPos = voxel_getLocalPosition(voxelPos);
//            float sampleDist = distance(lightLocalPos, localPos);
//
//            float light_att = GetLightAttenuation(sampleDist, lightRange);
//
//            lighting += light_att * lightColor;
//        }
//    #endif

    return BLOCK_LUX * lighting;
}
