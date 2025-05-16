const float CloudShadowDepth = 60.0;
const float CloudShadowMinF = 0.16;


float SampleCloudShadows(const in vec3 localPos) {
    float cloudShadowF = 1.0;

    vec3 worldPos = localPos + ap.camera.pos;

    vec3 cloudPos = (cloudHeight-worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir + worldPos;
    float cloudDensity = CloudShadowDepth * SampleCloudDensity(cloudPos);

    cloudShadowF = exp(-VL_ShadowTransmit * cloudDensity);
    cloudShadowF = max(cloudShadowF, CloudShadowMinF);

    return cloudShadowF;
}
