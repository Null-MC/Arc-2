vec3 SampleSkyIrradiance(const in vec3 localNormal, const in float lmcoord_y) {
    vec2 skyIrradianceCoord = DirectionToUV(localNormal);
    vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb * 1000.0;
    return (SKY_AMBIENT * _pow2(lmcoord_y)) * (skyIrradiance + Sky_MinLight);
}
