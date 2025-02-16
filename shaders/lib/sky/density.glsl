const float AirDensityF = SKY_FOG_DENSITY * 0.01;


float GetSkyDensity(const in vec3 localPos) {
    return mix(AirDensityF, 1.0, ap.world.rainStrength);


//    //    float sampleY = localPos.y + ap.camera.pos.y;
//    vec3 sampleWorldPos = localPos + ap.camera.pos;
//    float sampleDensity = clamp((sampleWorldPos.y - SKY_SEA_LEVEL) / (200.0), 0.0, 1.0);
//
//    float p = mix(8.0, 1.0, ap.world.rainStrength);
//    sampleDensity = pow(1.0 - sampleDensity, p);
//
//    float nightF = max(1.0 - Scene_LocalSunDir.y, 0.0);
//    float densityF = fma(nightF, 5.0, 1.0);
//    densityF = mix(densityF, 40.0, ap.world.rainStrength);
//
//    densityF *= AirDensityF * sampleDensity;
//
//    #ifdef FOG_NOISE
//        vec3 local_skyPos = sampleWorldPos; //localPos + ap.camera.pos;
//        local_skyPos.y -= SKY_SEA_LEVEL;
//        local_skyPos /= 80.0;//(ATMOSPHERE_MAX - SKY_SEA_LEVEL);
//        local_skyPos.xz /= (256.0/32.0);// * 4.0;
//        //local_skyPos.xz *= 0.4;// * 4.0;
//
//        float fogNoise = 0.0;
//        fogNoise = textureLod(texFogNoise, local_skyPos, 0).r;
//        fogNoise *= 1.0 - textureLod(texFogNoise, local_skyPos * 0.33, 0).r;
//        //                fogNoise = pow(fogNoise, 2);
//        fogNoise = fogNoise*fogNoise;
//        fogNoise = fogNoise*fogNoise;
//
//        fogNoise *= 100.0;
//
//        densityF = densityF * fogNoise + densityF; //pow(fogNoise, 4.0) * 20.0;
//    #endif
//
//    return densityF * 0.001;
}
