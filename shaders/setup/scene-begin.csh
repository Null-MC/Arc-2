#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout (local_size_x = 4, local_size_y = 1, local_size_z = 1) in;

uniform sampler2D texSkyIrradiance;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/erp.glsl"


void main() {
    if (gl_LocalInvocationIndex == 0u) {
        const vec3 worldUp = vec3(0.0, 1.0, 0.0);

        vec2 skyIrradianceCoord = DirectionToUV(worldUp);
        Scene_SkyIrradianceUp = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;

        Scene_SkyBrightnessSmooth = mix(ap.camera.brightness.y, Scene_SkyBrightnessSmooth, exp(-2.0 * ap.time.delta));

        shadowModelViewInv = inverse(ap.celestial.view);
    }

    shadowProjectionInv[gl_LocalInvocationIndex] = inverse(ap.celestial.projection[gl_LocalInvocationIndex]);
}
