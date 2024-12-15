// #define DEBUG_WHITE_WORLD

#define MATERIAL_FORMAT 1 // [0 1 2]

const float BLOCKLIGHT_TEMP = 3400.0;

const float SEA_LEVEL = 60.0;
const float ATMOSPHERE_MAX = 2200.0;
const float SUN_SIZE = 2.2;
const float MOON_SIZE = 3.4;

const float SUN_LUMINANCE = 4000.0;
const float EMISSION_BRIGHTNESS = 100.0;
const float MOON_LUMINANCE = 0.16;
const float STAR_LUMINANCE = 0.10;
const float SKY_LUMINANCE = 16.0;

const float SUN_BRIGHTNESS = 48.0;
const float MOON_BRIGHTNESS = 0.016;
const float SKY_BRIGHTNESS = 12.0;
const float BLOCKLIGHT_BRIGHTNESS = 4.0;

const float SKY_AMBIENT = 1.0;

const int SHADOW_PCF_SAMPLES = 8;

const float Exposure_minLogLum = -10.50;
const float Exposure_maxLogLum =  12.75;

const float shadowMapResolution = 1024.0;
const float sunPathRotation = 25.0;
const float cloudHeight = 192.0;
