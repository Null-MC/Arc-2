const float CloudShadowDepth = 300.0;
const float CloudShadowMinF = 0.0;
//const float CloudShadowHorizonF = 0.5;


float SampleCloudShadows(const in vec3 localPos) {
    float cloudShadowF = 1.0;

    vec3 worldPos = localPos + ap.camera.pos;

    vec3 cloudPos = abs((cloudHeight-worldPos.y) / Scene_LocalLightDir.y) * Scene_LocalLightDir + worldPos;
    float cloudDensity = CloudShadowDepth * SampleCloudDensity(cloudPos);

    cloudShadowF = exp(-cloudDensity * VL_ShadowTransmit);

    float CloudShadowHorizonF = 1.0 - max(ap.world.rain, ap.world.thunder);

    float horizonF = smoothstep(0.15, 0.30, Scene_LocalLightDir.y);
    cloudShadowF = mix(CloudShadowHorizonF, cloudShadowF, horizonF);

    cloudShadowF = CloudShadowMinF + (1.0 - CloudShadowMinF) * cloudShadowF;

    return cloudShadowF;
}
