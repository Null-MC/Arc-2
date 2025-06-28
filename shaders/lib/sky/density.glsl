float GetSkyDensity(const in vec3 localPos) {
    float density = Scene_SkyFogDensityF;

    density = mix(density, VL_RainDensity, ap.world.rain);
    density = mix(density, VL_ThunderDensity, ap.world.thunder);

    vec3 worldPos = localPos + ap.camera.pos;
    density *= 1.0 - saturate((worldPos.y - Scene_SkyFogSeaLevel) / 800.0);

    #ifdef FOG_CAVE_ENABLED
//        uint blockLightCoord = iris_getBlockAtPos(ivec3(floor(worldPos))).y;
//        float voxelSkyLightF = unpackUnorm2x16(blockLightCoord).y;
//        voxelSkyLightF = saturate(voxelSkyLightF / 240.0);

        float caveFogF = 1.0 - Scene_SkyBrightnessSmooth;
        caveFogF = _pow3(caveFogF);

        //float caveDensity = FOG_CAVE_DENSITY;
        density = mix(density, FOG_CAVE_DENSITY, caveFogF);
    #endif

    return density;
}

#ifdef SKY_FOG_NOISE
    float SampleFogNoise(const in vec3 localPos) {
        float viewDist = length(localPos);
        if (viewDist >= 48.0) return 1.0;

        vec3 skyPos = localPos + ap.camera.pos;
        skyPos.y -= Scene_SkyFogSeaLevel;

        vec3 samplePos = skyPos;
        //samplePos /= 10.0;//(ATMOSPHERE_MAX - SKY_SEA_LEVEL);
        samplePos.y *= 0.25;
        samplePos.xz /= (256.0/32.0);// * 4.0;

        float fogNoise = 0.0;
        fogNoise = textureLod(texFogNoise, samplePos, 0).r;
        fogNoise *= 1.0 - textureLod(texFogNoise, samplePos * 0.33, 0).r;

//        //fogNoise = pow(fogNoise, 3.6);
//        float threshold_min = mix(0.3, 0.25, ap.world.rain);
//        float threshold_max = threshold_min + 0.3;
//        fogNoise = smoothstep(threshold_min, 1.0, fogNoise);

        //float fogStrength = exp(-0.2 * max(skyPos.y, 0.0));

        //        float cloudMin = smoothstep(200.0, 220.0, skyPos.y);
        //        float cloudMax = smoothstep(260.0, 240.0, skyPos.y);
        //        fogStrength = max(fogStrength, cloudMin * cloudMax);

        //fogNoise *= fogStrength;
        //fogNoise *= 100.0;

        float blendF = smoothstep(0.0, 1.0, viewDist / 48.0);
        fogNoise *= 1.0 - blendF;

        return max(1.0 - 3.0 * fogNoise, 0.0);
    }
#endif
