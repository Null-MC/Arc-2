#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"


void main() {
    float u = gl_FragCoord.x / 256.0;
    float v = gl_FragCoord.y / 64.0;

    float sunCosTheta = 2.0*u - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, v);
    
    vec3 pos = vec3(0.0, height, 0.0); 
    vec3 sunDir = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));
    
    outColor = vec4(getSunTransmittance(pos, sunDir), 1.0);
}
