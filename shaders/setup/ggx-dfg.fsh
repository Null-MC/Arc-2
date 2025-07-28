#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec2 outColor;

in vec2 uv;

#include "/lib/common.glsl"
//#include "/lib/buffers/scene.glsl"


const int SAMPLE_COUNT = 16;

float VanDerCorput(in float n, const in int base) {
    float invBase = 1.0 / base;
    float denom = 1.0;
    float result = 0.0;

    for (int i = 1; i < 32; i++) {
        if (n > 0) {
            float denom = mod(n, 2.0);
            result = result + denom * invBase;
            invBase = invBase / 2.0;
            n = floor(n / 2.0);
        }
    }

    return result;
}

vec2 Hammersley(const in int i, const in float N) {
    return vec2(i/N, VanDerCorput(i, 2));
}

vec3 ImportanceSampleGGX(vec2 Xi, const in vec3 N, const in float roughness) {
    float a = roughness*roughness;

    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (a*a - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta*cosTheta);

    // from spherical coordinates to cartesian coordinates
    vec3 H = vec3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);

    // from tangent-space vector to world-space sample vector
    vec3 up;
    if (abs(N.z) < 0.999)
        up = vec3(0.0, 0.0, 1.0);
    else
        up = vec3(1.0, 0.0, 0.0);

    vec3 tangent = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);

    vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
}

float GeometrySchlickGGX(float NoV, float roughness) {
    float a = roughness;
    float k = a*a / 2.0;

    float denom = NoV * (1.0 - k) + k;
    return NoV / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NoV = max(dot(N, V), 0.0);
    float NoL = max(dot(N, L), 0.0);

    float ggx2 = GeometrySchlickGGX(NoV, roughness);
    float ggx1 = GeometrySchlickGGX(NoL, roughness);

    return ggx1 * ggx2;
}


void main() {
    float NoV = uv.x;//gl_FragCoord.x / 256.0;
    float roughness = uv.y;//gl_FragCoord.y / 256.0;

    vec3 V = vec3(sqrt(1.0 - NoV*NoV), 0.0, NoV);
    vec3 N = vec3(0.0, 0.0, 1.0);
    vec2 result = vec2(0.0);

    for (int i = 0; i < SAMPLE_COUNT; i++) {
        vec2 Xi = Hammersley(i, SAMPLE_COUNT);
        vec3 H = ImportanceSampleGGX(Xi, N, roughness);
        vec3 L = normalize(H * dot(V, H) * 2.0 - V);

        float NoL = max(L.z, 0.0);
        float NoH = max(H.z, 0.0);
        float VoH = max(dot(V, H), 0.0);

        if (NoL > 0.0) {
            float G = GeometrySmith(N, V, L, roughness);
            float G_Vis = (G * VoH) / (NoH * NoV);
            float Fc = pow(1.0 - VoH, 5);

            result += vec2(1.0 - Fc, Fc) * G_Vis;
        }
    }

    result /= SAMPLE_COUNT;

    outColor = saturate(result);
}
