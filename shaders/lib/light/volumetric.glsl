const float mieScatteringF = 0.08;
const float mieAbsorptionF = 0.01;

const float VL_RainDensity = 0.18;
const float VL_ThunderDensity = 0.12;

const float VL_WaterPhaseF =  0.86;
const float VL_WaterPhaseB = -0.14;
const float VL_WaterPhaseM =  0.65;
const float VL_WaterDensity = 0.080;

const float VL_ShadowTransmit = mieAbsorptionF;//0.02;

vec3 VL_WaterScatter = RgbToLinear(vec3(0.545, 0.682, 0.690));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.141, 0.671, 0.741));
vec3 VL_WaterAmbient = RgbToLinear(vec3(0.325, 0.588, 0.439));
