#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyView;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/sampling/erp.glsl"
#include "/lib/noise/ign.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"


vec3 CalculateIrradiance(const in vec3 normal) {
    const float sampleDelta = 0.2; //0.025;

    vec3 up    = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, normal));
    up         = normalize(cross(normal, right));

    mat3 tbn = mat3(right, up, normal);

    vec3 skyPos = getSkyPosition(vec3(0.0));

    float dither1 = InterleavedGradientNoise(gl_FragCoord.xy + ap.time.frames) / (TAU / sampleDelta);
    float dither2 = InterleavedGradientNoise(gl_FragCoord.xy + ap.time.frames+2) / (0.5*PI / sampleDelta);

    float nrSamples = 0.0;
    vec3 irradiance = vec3(0.0);

    for (float phi = dither1; phi < TAU; phi += sampleDelta) {
        float cos_phi = cos(phi);
        float sin_phi = sin(phi);

        for (float theta = dither2; theta < 0.5*PI; theta += sampleDelta) {
            // spherical to cartesian (in tangent space)
            float cos_theta = cos(theta);
            float sin_theta = sin(theta);

            vec3 tangentSample = vec3(
                sin_theta * cos_phi,
                sin_theta * sin_phi,
                cos_theta);

            // tangent space to world
            //tangentSample = vec3(0.0, 0.0, 1.0);
            vec3 sampleVec = normalize(tbn * tangentSample);

            // vec2 uv = DirectionToUV(sampleVec);
            // vec3 skyColor = textureLod(texSkyView, uv, 0).rgb;

            vec3 skyColor = getValFromSkyLUT(texSkyView, skyPos, sampleVec, Scene_LocalSunDir);

//            if (rayIntersectSphere(skyPos, sampleVec, groundRadiusMM) < 0.0) {
//                float sunLum = SUN_LUMINANCE * sun(sampleVec, Scene_LocalSunDir);
//                float moonLum = MOON_LUMINANCE * moon(sampleVec, -Scene_LocalSunDir);
//
//                vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, sampleVec);
//
//                skyColor += (sunLum + moonLum) * skyTransmit;
//            }

            irradiance += skyColor * (cos_theta * sin_theta);
            nrSamples++;
        }
    }

    return irradiance / nrSamples;
}

void main() {
    vec3 viewDir = DirectionFromUV(uv);
    vec3 irradiance = CalculateIrradiance(viewDir);

    outColor = vec4(irradiance * PI, 0.1);
}
