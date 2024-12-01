#version 430 core

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D texSkyView;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/erp.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"


vec3 CalculateIrradiance(const in vec3 normal) {
    const float sampleDelta = 0.2;

    vec3 up    = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(up, normal));
    up         = normalize(cross(normal, right));

    vec3 skyPos = getSkyPosition(vec3(0.0));
    vec3 sunDir = normalize(mul3(playerModelViewInverse, sunPosition));

    float nrSamples = 0.0;
    vec3 irradiance = vec3(0.0);  
    for (float phi = 0.0; phi < TAU; phi += sampleDelta) {
        float cos_phi = cos(phi);
        float sin_phi = sin(phi);

        for (float theta = 0.0; theta < 0.5*PI; theta += sampleDelta) {
            // spherical to cartesian (in tangent space)
            float cos_theta = cos(theta);
            float sin_theta = sin(theta);

            vec3 tangentSample = vec3(
                sin_theta * cos_phi,
                sin_theta * sin_phi,
                cos_theta);

            // tangent space to world
            vec3 sampleVec =
                tangentSample.x * right +
                tangentSample.y * up +
                tangentSample.z * normal;

            sampleVec = normalize(sampleVec);

            // vec2 uv = DirectionToUV(sampleVec);
            // vec3 skyColor = textureLod(texSkyView, uv, 0).rgb;

            vec3 skyColor = getValFromSkyLUT(texSkyView, skyPos, sampleVec, sunDir);

            irradiance += skyColor * (cos_theta * sin_theta);
            nrSamples++;
        }
    }

    return PI * (irradiance / nrSamples);
}

void main() {
    vec3 viewDir = DirectionFromUV(uv);
    vec3 irradiance = CalculateIrradiance(viewDir);

    outColor = vec4(20.0 * irradiance, 1.0);
}
