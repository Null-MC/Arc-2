#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyView;

#include "/settings.glsl"
#include "/lib/common.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/stars.glsl"


vec3 sun(vec3 rayDir, vec3 sunDir) {
    const float sunSolidAngle = SUN_SIZE * (PI/180.0);
    const float minSunCosTheta = cos(sunSolidAngle);

    float cosTheta = dot(rayDir, sunDir);
    if (cosTheta >= minSunCosTheta) return vec3(1.0);
    
    return vec3(0.0);
}


void iris_emitFragment() {
    vec3 sunDir = normalize(mul3(playerModelViewInverse, sunPosition));
    
    vec3 ndcPos = vec3(gl_FragCoord.xy / screenSize, 1.0) * 2.0 - 1.0;
    vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    vec3 localPos = mul3(playerModelViewInverse, viewPos);
    vec3 localViewDir = normalize(localPos);
    
    vec3 skyPos = getSkyPosition(vec3(0.0));
    vec3 colorFinal = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localViewDir, sunDir);

    if (rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) < 0.0) {
        // Bloom should be added at the end, but this is subtle and works well.
        vec3 sunLum = 200.0 * sun(localViewDir, sunDir);

        // Use smoothstep to limit the effect, so it drops off to actual zero.
        // sunLum = 20.0 * smoothstep(0.002, 1.0, sunLum);
    
        vec3 starViewDir = getStarViewDir(localViewDir);
        vec3 starLight = 0.4 * GetStarLight(starViewDir);
        // colorFinal += starLight;

        // If the sun value is applied to this pixel, we need to calculate the transmittance to obscure it.
        vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, localViewDir);

        colorFinal += (sunLum + starLight) * skyTransmit;
    }
    
    outColor = vec4(colorFinal, 1.0);
}
