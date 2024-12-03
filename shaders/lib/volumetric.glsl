const int VL_MaxSamples = 32;

const float VL_Scatter = 0.0012;
const float VL_Transmit = 0.0002;
const float VL_RainDensity = 6.0;

vec3 VL_WaterScatter = 0.5*RgbToLinear(vec3(0.263, 0.380, 0.376));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.051, 0.545, 0.588));


float GetSkyDensity(const in vec3 localPos) {
    float sampleY = localPos.y + cameraPos.y;
    float sampleDensity = clamp((sampleY - SEA_LEVEL) / (ATMOSPHERE_MAX - SEA_LEVEL), 0.0, 1.0);
    sampleDensity = pow(1.0 - sampleDensity, 12.0);

    sampleDensity *= VL_RainDensity*rainStrength + 1.0;
    return sampleDensity;
}
