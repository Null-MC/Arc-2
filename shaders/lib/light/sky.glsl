vec3 GetSkyLight(const in vec3 localPos) {
    vec3 skyPos = getSkyPosition(localPos);
    vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
    vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
    vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;

    return skyLight;
}
