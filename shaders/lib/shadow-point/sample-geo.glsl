void sample_AllPointLights(inout vec3 diffuse, inout vec3 specular, const in vec3 localPos, const in vec3 localGeoNormal, const in vec3 localTexNormal, const in vec3 albedo, const in float f0_metal, const in float roughL) {
    vec3 localViewDir = -normalize(localPos);
    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

    const float offsetBias = 0.8;
    const float normalBias = 0.04;
    vec3 localSamplePos = normalBias * localGeoNormal + localPos;

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(0.02 * localGeoNormal + localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = LightBinMap[lightBinIndex].shadowLightCount;
    #else
        const uint maxLightCount = LIGHTING_SHADOW_MAX_COUNT;
    #endif

    for (uint i = 0u; i < LIGHTING_SHADOW_BIN_MAX_COUNT; i++) {
        if (i >= maxLightCount) break;

        #ifdef LIGHTING_SHADOW_BIN_ENABLED
            uint lightIndex = LightBinMap[lightBinIndex].lightList[i].shadowIndex;
        #else
            uint lightIndex = i;
        #endif

        uint blockId = ap.point.block[lightIndex];
        #ifndef LIGHTING_SHADOW_BIN_ENABLED
            if (blockId == uint(-1)) continue;
        #endif

        float lightRange = iris_getEmission(blockId);
        lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);

        vec3 lightColor = iris_getLightColor(blockId).rgb;
        lightColor = RgbToLinear(lightColor);

        float lightSize = iris_isFullBlock(blockId) ? 1.0 : 0.15;

        vec3 fragToLight = ap.point.pos[lightIndex].xyz - localSamplePos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;
        vec3 lightDir = sampleDir;

        float geo_facing = step(0.0, dot(localGeoNormal, sampleDir));

        float lightShadow = geo_facing * sample_PointLight(localSamplePos, lightSize, lightRange, offsetBias, lightIndex);



        vec3 H = normalize(lightDir + localViewDir);

        float LoHm = max(dot(lightDir, H), 0.0);
        float NoLm = max(dot(localTexNormal, lightDir), 0.0);

        float D = NoLm * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

        float NoHm = max(dot(localTexNormal, H), 0.0);

        const bool isUnderWater = false;
        vec3 F = material_fresnel(albedo, f0_metal, roughL, NoLm, isUnderWater);
        float S = SampleLightSpecular(NoLm, NoHm, LoHm, roughL);


        diffuse  += BLOCK_LUX * D * lightShadow * (1.0 - F) * lightColor;
        specular += BLOCK_LUX * S * lightShadow * F * lightColor;
    }

    #if defined(LIGHTING_SHADOW_BIN_ENABLED) && defined(LIGHTING_SHADOW_VOXEL_FILL)
        // sample non-shadow lights
        uint offset = maxLightCount;
        maxLightCount = offset + LightBinMap[lightBinIndex].lightCount;
        for (uint i = offset; i < LIGHTING_SHADOW_BIN_MAX_COUNT; i++) {
            if (i >= maxLightCount) break;

            vec3 voxelPos = GetLightVoxelPos(LightBinMap[lightBinIndex].lightList[i].voxelIndex) + 0.5;
            uint blockId = SampleVoxelBlock(voxelPos);

            float lightRange = iris_getEmission(blockId);
            lightRange *= (LIGHTING_SHADOW_RANGE * 0.01);

            vec3 lightColor = iris_getLightColor(blockId).rgb;
            lightColor = RgbToLinear(lightColor);

            vec3 lightLocalPos = voxel_getLocalPosition(voxelPos);
            vec3 fragToLight = lightLocalPos - localSamplePos;
            float sampleDist = length(fragToLight);
            vec3 sampleDir = fragToLight / sampleDist;
            vec3 lightDir = sampleDir;

            float geo_facing = step(0.0, dot(localGeoNormal, sampleDir));
            float light_att = GetLightAttenuation(sampleDist, lightRange);
            float lightShadow = geo_facing * light_att;



            vec3 H = normalize(lightDir + localViewDir);

            float LoHm = max(dot(lightDir, H), 0.0);
            float NoLm = max(dot(localTexNormal, lightDir), 0.0);

            float D = NoLm * SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);

            float NoHm = max(dot(localTexNormal, H), 0.0);

            const bool isUnderWater = false;
            vec3 F = material_fresnel(albedo, f0_metal, roughL, NoLm, isUnderWater);
            float S = SampleLightSpecular(NoLm, NoHm, LoHm, roughL);


            diffuse  += BLOCK_LUX * D * lightShadow * (1.0 - F) * lightColor;
            specular += BLOCK_LUX * S * lightShadow * F * lightColor;
        }
    #endif

    //return blockLighting;
}
