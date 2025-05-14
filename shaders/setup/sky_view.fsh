#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyMultiScatter;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/sky/common.glsl"
// #include "/lib/sky/view.glsl"

const int numScatteringSteps = 32;


vec3 raymarchScattering(vec3 pos, vec3 rayDir, vec3 sunDir, float tMax, float numSteps) {
    float cosTheta = dot(rayDir, sunDir);
    
	float miePhaseValue = getMiePhase(cosTheta);
	float rayleighPhaseValue = getRayleighPhase(-cosTheta);
    
    vec3 lum = vec3(0.0);
    vec3 transmittance = vec3(1.0);
    float t = 0.0;// 0.00001*(0.25 * farPlane);

    for (float i = 0.0; i < numSteps; i += 1.0) {
        float newT = ((i + 0.3)/numSteps)*tMax;
        float dt = newT - t;
        t = newT;
        
        vec3 newPos = pos + t*rayDir;

        vec3 rayleighScattering, extinction;
        float mieScattering;
        getScatteringValues(newPos, rayleighScattering, mieScattering, extinction);
        
        vec3 sampleTransmittance = exp(-dt*extinction);

        vec3 sunTransmittance = getValFromTLUT(texSkyTransmit, newPos, sunDir);
        vec3 moonTransmittance = getValFromTLUT(texSkyTransmit, newPos, -sunDir);

        vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, newPos, sunDir);

        vec3 rayleighInScattering_sun = rayleighScattering * (rayleighPhaseValue * sunTransmittance * SUN_LUX + psiMS);
        vec3 mieInScattering_sun = mieScattering * (miePhaseValue*sunTransmittance * SUN_LUX + psiMS);

        vec3 rayleighInScattering_moon = rayleighScattering * (rayleighPhaseValue * moonTransmittance * MOON_LUX + psiMS);
        vec3 mieInScattering_moon = mieScattering * (miePhaseValue * moonTransmittance * MOON_LUX + psiMS);

        vec3 inScattering = (rayleighInScattering_sun + rayleighInScattering_moon + mieInScattering_sun + mieInScattering_moon);

        // Integrated scattering within path segment.
        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        lum += scatteringIntegral*transmittance;
        
        transmittance *= sampleTransmittance;
    }

    return lum;
}


void main() {
    float u = uv.x;//gl_FragCoord.x / 256.0;
    float v = uv.y;//gl_FragCoord.y / 256.0;
    
    float azimuthAngle = (u - 0.5) * 2.0*PI;

    // Non-linear mapping of altitude. See Section 5.3 of the paper.
    float adjV;
    if (v < 0.5) {
		float coord = 1.0 - 2.0*v;
		adjV = -coord*coord;
	} else {
		float coord = v*2.0 - 1.0;
		adjV = coord*coord;
	}
    
    vec3 skyPos = getSkyPosition(vec3(0.0));
    float height = length(skyPos);
    vec3 up = skyPos / height;

    float elevation2 = max(height * height - groundRadiusMM * groundRadiusMM, 0.0);
    float horizonAngle = safeacos(sqrt(elevation2) / height) - 0.5*PI;
    float altitudeAngle = adjV*0.5*PI - horizonAngle;
    
    float cosAltitude = cos(altitudeAngle);
    vec3 rayDir = vec3(cosAltitude*sin(azimuthAngle), sin(altitudeAngle), -cosAltitude*cos(azimuthAngle));
    
    float sunAltitude = (0.5*PI) - acos(dot(Scene_LocalSunDir, up));
    vec3 sunDirEx = vec3(0.0, sin(sunAltitude), -cos(sunAltitude));
    
    float atmoDist = rayIntersectSphere(skyPos, rayDir, atmosphereRadiusMM);
    float groundDist = rayIntersectSphere(skyPos, rayDir, groundRadiusMM);
    float tMax = (groundDist < 0.0) ? atmoDist : groundDist;

    vec3 lum = raymarchScattering(skyPos, rayDir, sunDirEx, tMax, float(numScatteringSteps));

    outColor = vec4(lum, 1.0);
}
