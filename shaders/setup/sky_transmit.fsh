#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;

#include "/lib/common.glsl"

#include "/lib/hg.glsl"
#include "/lib/sky/common.glsl"


const int sunTransmittanceSteps = 40;


void main() {
    vec2 uv = gl_FragCoord.xy / textureSize(texSkyTransmit, 0);

    float sunCosTheta = 2.0*uv.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    vec3 pos = vec3(0.0, height, 0.0); 
    vec3 sunDir = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));

    vec3 transmittance = vec3(0.0);
    if (rayIntersectSphere(pos, sunDir, groundRadiusMM) <= 0.0) {
        float atmoDist = rayIntersectSphere(pos, sunDir, atmosphereRadiusMM);
        float t = 0.0;
        
        transmittance = vec3(1.0);

        for (int i = 0; i < sunTransmittanceSteps; i++) {
            float newT = ((i + 0.3)/sunTransmittanceSteps)*atmoDist;
            float dt = newT - t;
            t = newT;
            
            vec3 newPos = pos + t*sunDir;
            
            vec3 rayleighScattering, extinction;
            float mieScattering;
            getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
            
            transmittance *= exp(-dt*extinction);
        }
    }

    outColor = vec4(transmittance, 1.0);
}
