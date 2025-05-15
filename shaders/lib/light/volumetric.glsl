//const float VL_Phase = 0.86;
//const float VL_Scatter  = 0.90;
//const float VL_Transmit = 0.012;
//const float VL_AmbientF = 1.0;

//const float VL_RainPhase = 0.72;
//const float VL_RainScatter  = 0.090;
//const float VL_RainTransmit = 0.012;

const float mieScatteringF = 0.04;
const float mieAbsorptionF = 0.02;

const float VL_WaterPhaseF =  0.86;
const float VL_WaterPhaseB = -0.14;
const float VL_WaterPhaseM =  0.65;
const float VL_WaterDensity = 0.20;

const float VL_ShadowTransmit = 0.08;

vec3 VL_WaterScatter = RgbToLinear(vec3(0.545, 0.682, 0.690));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.106, 0.498, 0.549));
vec3 VL_WaterAmbient = 12.0 * RgbToLinear(vec3(0.325, 0.588, 0.439));
