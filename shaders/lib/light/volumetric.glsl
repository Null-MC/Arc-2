const float mieScatteringF = 0.0050;
const float mieAbsorptionF = 0.0015;

//const float VL_RainDensity = 0.48;
//const float VL_ThunderDensity = 0.12;

const float VL_WaterPhaseF =  0.86;
const float VL_WaterPhaseB = -0.14;
const float VL_WaterPhaseM =  0.65;
const float VL_WaterDensity = 1.00;

const float VL_MinLight = 8.0;

const float VL_ShadowTransmit = mieAbsorptionF;//0.02;

const vec3 VL_WaterScatter = 0.001*_RgbToLinear(vec3(0.651, 0.780, 0.788));
const vec3 VL_WaterTransmit = _RgbToLinear(1.0 - vec3(0.125, 0.522, 0.58));
const vec3 VL_WaterAmbient = 1.0*_RgbToLinear(vec3(0.325, 0.588, 0.439));
