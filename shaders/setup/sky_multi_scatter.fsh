#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;

#include "/settings.glsl"
#include "/lib/common.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/multi_scatter.glsl"


void main() {
    float u = uv.x;//gl_FragCoord.x / 32.0;
    float v = uv.y;//gl_FragCoord.y / 32.0;
    
    float sunCosTheta = 2.0*u - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, v);
    
    vec3 pos = vec3(0.0, height, 0.0); 
    vec3 sunDir = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));
    
    vec3 lum, f_ms;
    getMulScattValues(pos, sunDir, lum, f_ms);
    
    // Equation 10 from the paper.
    vec3 psi = lum  / (1.0 - f_ms); 
    outColor = vec4(psi, 1.0);
}
