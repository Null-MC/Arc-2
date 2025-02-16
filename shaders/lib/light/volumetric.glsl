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

vec3 VL_WaterScatter = 0.001 * RgbToLinear(vec3(0.545, 0.682, 0.690));
vec3 VL_WaterTransmit = RgbToLinear(1.0 - vec3(0.447, 0.627, 0.741));
vec3 VL_WaterAmbient = RgbToLinear(vec3(0.235, 0.353, 0.361));
