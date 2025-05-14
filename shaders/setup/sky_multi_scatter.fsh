#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;

#include "/settings.glsl"
#include "/lib/common.glsl"

#include "/lib/sky/common.glsl"


const float mulScattSteps = 20.0;
const int sqrtSamples = 8;

vec3 getSphericalDir(float theta, float phi) {
    float cosPhi = cos(phi);
    float sinPhi = sin(phi);
    float cosTheta = cos(theta);
    float sinTheta = sin(theta);
    return vec3(sinPhi*sinTheta, cosPhi, sinPhi*cosTheta);
}

void getMulScattValues(vec3 pos, vec3 sunDir, out vec3 lumTotal, out vec3 fms) {
    lumTotal = vec3(0.0);
    fms = vec3(0.0);

    const float invSamples = 1.0 / float(sqrtSamples*sqrtSamples);

    for (int i = 0; i < sqrtSamples; i++) {
        for (int j = 0; j < sqrtSamples; j++) {
            // This integral is symmetric about theta = 0 (or theta = PI), so we
            // only need to integrate from zero to PI, not zero to 2*PI.
            float theta = PI * (i + 0.5) / sqrtSamples;
            float phi = safeacos(1.0 - 2.0*(j + 0.5) / sqrtSamples);
            vec3 rayDir = getSphericalDir(theta, phi);

            float atmoDist = rayIntersectSphere(pos, rayDir, atmosphereRadiusMM);
            float groundDist = rayIntersectSphere(pos, rayDir, groundRadiusMM);

            float tMax = atmoDist;
            if (groundDist > 0.0) {
                tMax = groundDist;
            }

            float VoL_sun = dot(rayDir, sunDir);
            float miePhase_sun = getMiePhase(VoL_sun);
            float rayleighPhase_sun = getRayleighPhase(-VoL_sun);

            float VoL_moon = -VoL_sun;
            float miePhase_moon = getMiePhase(VoL_moon);
            float rayleighPhase_moon = getRayleighPhase(-VoL_sun);

            vec3 lum = vec3(0.0), lumFactor = vec3(0.0), transmittance = vec3(1.0);

            float t = 0.0;
            for (float stepI = 0.0; stepI < mulScattSteps; stepI += 1.0) {
                float newT = ((stepI + 0.3)/mulScattSteps)*tMax;
                float dt = newT - t;
                t = newT;

                vec3 newPos = pos + t*rayDir;

                vec3 rayleighScattering, extinction;
                float mieScattering;
                getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);

                vec3 sampleTransmittance = exp(-dt*extinction);

                // Integrate within each segment.
                vec3 scatteringNoPhase = rayleighScattering + mieScattering;
                vec3 scatteringF = (scatteringNoPhase - scatteringNoPhase * sampleTransmittance) / extinction;
                lumFactor += transmittance*scatteringF;

                // This is slightly different from the paper, but I think the paper has a mistake?
                // In equation (6), I think S(x,w_s) should be S(x-tv,w_s).
                vec3 sunTransmittance = getValFromTLUT(texSkyTransmit, newPos, sunDir);
                vec3 moonTransmittance = getValFromTLUT(texSkyTransmit, newPos, -sunDir);

                vec3 rayleighInScattering_sun = rayleighScattering * rayleighPhase_sun;
                float mieInScattering_sun = mieScattering * miePhase_sun;

                vec3 rayleighInScattering_moon = rayleighScattering * rayleighPhase_moon;
                float mieInScattering_moon = mieScattering * miePhase_moon;

                vec3 inScattering = (rayleighInScattering_sun + mieInScattering_sun) * sunTransmittance * SUN_LUX;
                                  + (rayleighInScattering_moon + mieInScattering_moon) * moonTransmittance * MOON_LUX;

                // Integrated scattering within path segment.
                vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

                lum += scatteringIntegral*transmittance;
                transmittance *= sampleTransmittance;
            }

            if (groundDist > 0.0) {
                vec3 hitPos = pos + groundDist*rayDir;
                if (dot(pos, sunDir) > 0.0) {
                    hitPos = normalize(hitPos)*groundRadiusMM;
                    lum += transmittance*groundAlbedo*getValFromTLUT(texSkyTransmit, hitPos, sunDir);
                }
            }

            fms += lumFactor*invSamples;
            lumTotal += lum*invSamples;
        }
    }
}


void main() {
    float sunCosTheta = 2.0*uv.x - 1.0;
    float sunTheta = safeacos(sunCosTheta);
    float height = mix(groundRadiusMM, atmosphereRadiusMM, uv.y);
    
    vec3 pos = vec3(0.0, height, 0.0); 
    vec3 sunDir = normalize(vec3(0.0, sunCosTheta, -sin(sunTheta)));
    
    vec3 lum, f_ms;
    getMulScattValues(pos, sunDir, lum, f_ms);

    vec3 psi = lum  / (1.0 - f_ms); 
    outColor = vec4(psi, 1.0);
}
