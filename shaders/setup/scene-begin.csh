#version 430 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

uniform sampler2D texSkyIrradiance;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/erp.glsl"


void main() {
    const vec3 worldUp = vec3(0.0, 1.0, 0.0);

    vec2 skyIrradianceCoord = DirectionToUV(worldUp);
    vec3 skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
    Scene_SkyIrradianceUp = skyIrradiance * SKY_BRIGHTNESS;
    
    Scene_SkyBrightnessSmooth = mix(ap.camera.brightness.y, Scene_SkyBrightnessSmooth, exp(-2.0 * ap.frame.millis));
}
