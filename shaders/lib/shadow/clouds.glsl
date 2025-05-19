const float CloudShadowDepth = 100.0;
const float CloudShadowMinF = 0.1;


float SampleCloudShadows(const in vec3 localPos) {
    float cloudShadowF = 1.0;

    vec3 worldPos = localPos + ap.camera.pos;

    vec3 cloudPos = (cloudHeight-worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir + worldPos;
    float cloudDensity = CloudShadowDepth * SampleCloudDensity(cloudPos);

    cloudShadowF = exp(-VL_ShadowTransmit * cloudDensity);

    float horizonF = smoothstep(0.15, 0.30, Scene_LocalLightDir.y);
    cloudShadowF = mix(0.0, cloudShadowF, horizonF);

    cloudShadowF = CloudShadowMinF + (1.0 - CloudShadowMinF) * cloudShadowF;

    return cloudShadowF;
}
