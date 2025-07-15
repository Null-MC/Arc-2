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
#include "/lib/hg.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"


vec3 CalculateIrradiance(const in vec3 normal) {
    const vec2 sampleDelta = vec2(0.2, 0.1); //0.025;

    vec3 up    = vec3(0.0, 1.0, 0.0);
//    vec3 T = cross(normal, up);
//    T = mix(cross(normal, vec3(1.0, 0.0, 0.0)), T, step(EPSILON, dot(T, T)));
//    T = normalize(T);
//    vec3 S = normalize(cross(normal, T));
//    mat3 tbn = mat3(S, T, normal);

    vec3 right = normalize(cross(up, normal));
    up         = normalize(cross(normal, right));

    mat3 tbn = mat3(right, up, normal);

    vec3 skyPos = getSkyPosition(vec3(0.0));

    const ivec2 stepCount = ivec2(PI * vec2(2.0, 0.5) / sampleDelta);

    float dither1 = InterleavedGradientNoise(gl_FragCoord.xy + ap.time.frames*123.4) * sampleDelta.x;
    float dither2 = InterleavedGradientNoise(gl_FragCoord.xy+7.0 + ap.time.frames*234.5) * sampleDelta.y;

    float nrSamples = 0.0;
    vec3 irradiance = vec3(0.0);

    float phi = dither1;
    for (int x = 0; x < stepCount.x; x++) {
        float cos_phi = cos(phi);
        float sin_phi = sin(phi);

        float theta = dither2;
        for (int y = 0; y < stepCount.y; y++) {
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
//                skyColor += (sunLum * Scene_SunColor + moonLum) * skyTransmit;
//            }

            irradiance += skyColor * (cos_theta * sin_theta);
            nrSamples++;

            theta += sampleDelta.y;
        }

        phi += sampleDelta.x;
    }

    return irradiance / nrSamples * PI;// * (2.0 / PI);
}

void main() {
    vec3 viewDir = DirectionFromUV(uv);
    vec3 irradiance = CalculateIrradiance(viewDir);

    outColor = vec4(irradiance * 0.001, 0.1);
}
