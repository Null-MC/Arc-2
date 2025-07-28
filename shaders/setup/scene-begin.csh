#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

uniform sampler2D texSkyIrradiance;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/sampling/erp.glsl"


void mixTo(inout float value, const in float tgt, const in float down, const in float up, const in float speed) {
    if (value < tgt) value = min(value + up*speed, tgt);
    if (value > tgt) value = max(value + down*speed, tgt);
}


void main() {
    const vec3 worldUp = vec3(0.0, 1.0, 0.0);

    vec2 skyIrradianceCoord = DirectionToUV(worldUp);
    Scene_SkyIrradianceUp = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

    Scene_SkyBrightnessSmooth = mix(ap.camera.brightness.y, Scene_SkyBrightnessSmooth, exp(-2.0 * ap.time.delta));

    //ap.world.precipitation
    Scene_SkyPrecipitation = mix(step(1, ap.world.precipitation), Scene_SkyPrecipitation, exp(-0.4 * ap.time.delta));

    float weather_wetness = max(ap.world.rain * 0.7, ap.world.thunder);
    mixTo(World_SkyWetness, weather_wetness, -0.04, 0.40, ap.time.delta);
    mixTo(World_GroundWetness, weather_wetness, -0.01, 0.12, ap.time.delta);
}
