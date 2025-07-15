float GetSkyDensity(const in vec3 localPos) {
    vec3 worldPos = localPos + ap.camera.pos;
    float dayF = (ap.world.time % 24000) / 24000.0;
    float nightF = sin(dayF * TAU - 0.1);

    const float humidity = 0.15; // TODO: ask IMS for uniform
    float ground_density = mix(0.0, 0.08, humidity);
    ground_density = mix(ground_density, 1.1, saturate(-nightF));

    ground_density *= 1.0 / (1.0 + max(worldPos.y - Scene_SkyFogSeaLevel, 0.0));

    float weather_density = 0.0;
    weather_density = mix(weather_density, 0.04, ap.world.rain);
    weather_density = mix(weather_density, 0.07, ap.world.thunder);
    weather_density *= step(worldPos.y, cloudHeight);

    float density = Scene_SkyFogDensityF * (ground_density + weather_density);

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

        vec3 skyPos = localPos + ap.camera.pos;
        skyPos.y -= Scene_SkyFogSeaLevel;
        skyPos.xz *= 64.0/256.0;

        float density = 1.0;

        if (viewDist < 128.0) {
            vec3 samplePos = skyPos * 0.0625;
            float fogNoise = 1.0 - textureLod(texFogNoise, samplePos, 0).r;
            density *= max(2.0 - 1.8*fogNoise, 0.0);
        }

        if (viewDist < 32.0) {
            vec3 samplePos = skyPos * 0.25;
            float fogNoise = 1.0 - textureLod(texFogNoise, samplePos, 0).r;
            density *= max(3.0 - 2.8*fogNoise, 0.0);
        }

        return density;
    }
#endif
