const float VL_Phase = 0.86;
const float VL_Scatter  = 0.090;
const float VL_Transmit = 0.012;
const float VL_AmbientF = 1.0;

const float VL_RainPhase = 0.72;
const float VL_RainScatter  = 0.090;
const float VL_RainTransmit = 0.012;

const float VL_WaterPhaseF =  0.86;
const float VL_WaterPhaseB = -0.14;
const float VL_WaterPhaseM =  0.65;

vec3 VL_WaterScatter = 0.1 * RgbToLinear(vec3(0.545, 0.682, 0.690));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.447, 0.627, 0.741));
vec3 VL_WaterAmbient = RgbToLinear(vec3(0.235, 0.353, 0.361));

const float AirDensityF = SKY_FOG_DENSITY * 0.01;


float GetSkyDensity(const in vec3 localPos) {
    float sampleY = localPos.y + ap.camera.pos.y;
    float sampleDensity = clamp((sampleY - SKY_SEA_LEVEL) / (200.0), 0.0, 1.0);

    float p = mix(4.0, 1.0, ap.world.rainStrength);
    sampleDensity = pow(1.0 - sampleDensity, p);

    float nightF = max(1.0 - Scene_LocalSunDir.y, 0.0);
    float densityF = fma(nightF, 5.0, 1.0);
    densityF = mix(densityF, 40.0, ap.world.rainStrength);

    return AirDensityF * densityF * sampleDensity;
}
