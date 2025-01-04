// #define DEBUG_WHITE_WORLD

#define MATERIAL_EMISSION_POWER 2.2
// #define LPV_PER_FACE_LIGHTING
#define MATERIAL_ROUGH_REFRACT

#define CLOUDS_ENABLED
#define CLOUD_SHADOWS_ENABLED

#define MATERIAL_PARALLAX_MAXDIST 48


#define DEBUG_VIEW DEBUG_VIEW_SSAO
#define DEBUG_MATERIAL DEBUG_MAT_NONE

const float BLOCKLIGHT_TEMP = 3400.0;

const float ATMOSPHERE_MAX = 4200.0;
const float SUN_SIZE = 2.2;
const float MOON_SIZE = 3.4;

const float SUN_LUMINANCE = 4000.0;
const float EMISSION_BRIGHTNESS = 80.0;
const float MOON_LUMINANCE = 0.16;
const float STAR_LUMINANCE = 0.10;
const float SKY_LUMINANCE = 32.0;

const float SUN_BRIGHTNESS = 32.0;
const float MOON_BRIGHTNESS = 0.024;
const float SKY_BRIGHTNESS = 12.0;
const float BLOCKLIGHT_BRIGHTNESS = 4.0;

#if (defined LPV_ENABLED && defined LPV_RSM_ENABLED) || defined EFFECT_SSGI_ENABLED
	const float SKY_AMBIENT = 0.3;
#else
	const float SKY_AMBIENT = 0.5;
#endif

const int SHADOW_PCF_SAMPLES = 8;
const int SHADOW_PCSS_SAMPLES = 6;
const float Shadow_MaxPcfSize = 2.0;

const float Bloom_Power = 1.3;
const float Bloom_Strength = 0.04;

const float Exposure_minLogLum = POST_EXPOSURE_MIN;// -9.5;
const float Exposure_maxLogLum = POST_EXPOSURE_MAX;//  19.0;
const float Exposure_Speed = POST_EXPOSURE_SPEED;// 0.2;//2.1;

const float shadowMapResolution = 1024.0;
const float sunPathRotation = 25.0;
const float cloudHeight = 320.0;


// DO NOT EDIT
const float shadowPixelSize = 1.0 / shadowMapResolution;

#if defined MATERIAL_PARALLAX_ENABLED && defined RENDER_TERRAIN && MATERIAL_FORMAT != MAT_NONE
	#define RENDER_PARALLAX
#endif
