void sample_AllPointLights(inout vec3 diffuse, inout vec3 specular, const in vec3 localPos, const in vec3 localGeoNormal, const in vec3 localTexNormal, const in vec3 albedo, const in float f0_metal, const in float roughL, const in float sss) {
    vec3 localViewDir = -normalize(localPos);
    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

    const float offsetBias = 0.02;
    const float normalBias = 0.16;
    vec3 localSamplePos = normalBias * localGeoNormal + localPos;

    #ifdef LIGHTING_SHADOW_BIN_ENABLED
        vec3 voxelPos = voxel_GetBufferPosition(0.02 * localGeoNormal + localPos);
        ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
        int lightBinIndex = GetLightBinIndex(lightBinPos);

        uint maxLightCount = LightBinMap[lightBinIndex].shadowLightCount;
    #else
        const uint maxLightCount = LIGHTING_SHADOW_MAX_COUNT;
    #endif

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

        vec3 lightColor = iris_getLightColor(light.block).rgb;
        lightColor = RgbToLinear(lightColor);

        float lightSize = getLightSize(light.block);

        vec3 fragToLight = light.pos - localSamplePos;
        float sampleDist = length(fragToLight);
        vec3 sampleDir = fragToLight / sampleDist;
        vec3 lightDir = sampleDir;

        float geo_NoLm = max(dot(localGeoNormal, sampleDir), 0.0);
        float bias = offsetBias + sss;

        float lightShadow = sample_PointLight(-fragToLight, lightSize, lightRange, bias, lightIndex);

        float NoL = dot(localTexNormal, lightDir);
        float NoLm = max(NoL, 0.0);

        NoLm = min(NoLm, geo_NoLm);

        float sss_NoLm = max((NoLm + sss) / (1.0 + sss), 0.0);

        vec3 H = normalize(lightDir + localViewDir);

        float LoHm = max(dot(lightDir, H), 0.0);

        float D = sss_NoLm * SampleLightDiffuse(NoVm, sss_NoLm, LoHm, roughL);

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
