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

        vec3 skyPos = localPos + ap.camera.pos;
        skyPos.y -= Scene_SkyFogSeaLevel;
        skyPos.xz *= 64.0/256.0;

        float density = 1.0;

        if (viewDist < 128.0) {
            vec3 samplePos = skyPos * 0.0625;
            float fogNoise = textureLod(texFogNoise, samplePos, 0).r;
            density *= max(1.0 - 1.2*fogNoise, 0.0);
        }

        if (viewDist < 32.0) {
            vec3 samplePos = skyPos * 0.25;
            float fogNoise = textureLod(texFogNoise, samplePos, 0).r;
            density *= max(1.0 - 1.6*fogNoise, 0.0);
        }

        return density;
    }
#endif
