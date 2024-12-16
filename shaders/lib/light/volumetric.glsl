const float VL_Phase = 0.78;
const float VL_Scatter  = 0.0024;
const float VL_Transmit = 0.0006;
const float VL_AmbientF = 6.0;

const float VL_RainPhase = 0.42;
const float VL_RainScatter  = 0.090;
const float VL_RainTransmit = 0.014;

const float VL_WaterPhase = 0.36;
vec3 VL_WaterScatter = 0.25 * RgbToLinear(vec3(0.263, 0.380, 0.376));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.051, 0.545, 0.588));
vec3 VL_WaterAmbient = 2.0 * RgbToLinear(vec3(0.157, 0.839, 0.792));


float GetSkyDensity(const in vec3 localPos) {
    float sampleY = localPos.y + cameraPos.y;
    float sampleDensity = clamp((sampleY - SEA_LEVEL) / (200.0), 0.0, 1.0);

    float p = mix(16.0, 2.0, rainStrength);
    sampleDensity = pow(1.0 - sampleDensity, p);

    return sampleDensity;
}
