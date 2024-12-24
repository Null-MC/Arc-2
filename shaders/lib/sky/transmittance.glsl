void GetSkyLightTransmission(const in vec3 localPos, out vec3 sunTransmit, out vec3 moonTransmit) {
    vec3 skyPos = getSkyPosition(localPos);
    sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
}
