const float VL_Phase = 0.86;
const float VL_Scatter  = 0.090;
const float VL_Transmit = 0.012;
const float VL_AmbientF = 1.0;

const float VL_RainPhase = 0.42;
const float VL_RainScatter  = 0.600;
const float VL_RainTransmit = 0.180;

const float VL_WaterPhaseF =  0.56;
const float VL_WaterPhaseB = -0.16;
const float VL_WaterPhaseM =  0.92;

vec3 VL_WaterScatter = 0.5 * RgbToLinear(vec3(0.263, 0.380, 0.376));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.051, 0.545, 0.588));
vec3 VL_WaterAmbient = 0.5*RgbToLinear(vec3(0.157, 0.839, 0.792));


float GetSkyDensity(const in vec3 localPos) {
    float sampleY = localPos.y + cameraPos.y;
    float sampleDensity = clamp((sampleY - SKY_SEA_LEVEL) / (200.0), 0.0, 1.0);

    float p = mix(16.0, 4.0, rainStrength);
    sampleDensity = pow(1.0 - sampleDensity, p);

    float nightF = max(1.0 - Scene_LocalSunDir.y, 0.0);
    return 0.5 * (nightF * 0.9 + 0.1) * sampleDensity;
}
