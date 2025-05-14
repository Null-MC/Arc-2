#define FOG_CAVE_ENABLED
#define FOG_CAVE_DENSITY 0.8

#define MATERIAL_EMISSION_POWER 1
#define MATERIAL_ROUGH_REFRACT
#define MATERIAL_PARALLAX_MAXDIST 48

//#define REFRACTION_SNELL

#define VOXEL_GI_MAXFRAMES 60 // [60 120 240]

#ifdef LIGHTING_GI_SKYLIGHT
	#define VOXEL_GI_MAXSTEP 16
#else
	#define VOXEL_GI_MAXSTEP 4
#endif

#define EFFECT_SSAO_STRENGTH 1000


const float ATMOSPHERE_MAX = 4200.0;

const float SUN_SIZE = 2.2;
const float SUN_LUMINANCE = 16000000;//1.6e9;
const float SUN_LUX = 64000.0;

const float MOON_SIZE = 3.4;
const float MOON_LUMINANCE = 80.00;
const float MOON_LUX = 12.0;

const float STAR_LUMINANCE = 32.00;

const float BLOCKLIGHT_LUMINANCE = 32000.0;
const float BLOCK_LUX = 8000.0;


const float SUN_BRIGHTNESS = 64000.0;
const float MOON_BRIGHTNESS = 64.0;
//const float SKY_BRIGHTNESS = 19000.0;
const float BLOCKLIGHT_BRIGHTNESS = 800.0;

const float SKY_AMBIENT = 1.0;

//#if (defined LPV_ENABLED && defined LPV_RSM_ENABLED) || defined EFFECT_SSGI_ENABLED
//	const float SKY_AMBIENT = 1.0;
//#else
//	const float SKY_AMBIENT = 1.0;
//#endif

const int SHADOW_PCF_SAMPLES = 8;
const int SHADOW_PCSS_SAMPLES = 6;
const float SHADOW_PENUMBRA_SCALE = 64.0;
const float Shadow_MaxPcfSize = 0.8;

//const float Bloom_Power = 1.0;
//const float Bloom_Strength = 0.03;

const float PurkinjeStrength = 0.08;

//const float Exposure_minLogLum = POST_EXPOSURE_MIN;// -9.5;
//const float Exposure_maxLogLum = POST_EXPOSURE_MAX;//  19.0;
//const float Exposure_Speed = POST_EXPOSURE_SPEED;// 0.2;//2.1;

const float WaterTintMinDist = 1.0;
const float shadowMapResolution = float(SHADOW_RESOLUTION);
const float sunPathRotation = 25.0;
const float cloudHeight = 320.0;

const vec3 WhiteWorld_Value = vec3(0.8);


// DO NOT EDIT
const float shadowPixelSize = 1.0 / shadowMapResolution;

#if defined MATERIAL_PARALLAX_ENABLED && defined RENDER_TERRAIN && MATERIAL_FORMAT != MAT_NONE
	#define RENDER_PARALLAX
#endif

layout (std140, binding = 0) uniform SceneSettings {
	float Scene_SkyFogDensityF;
	float Scene_SkyFogSeaLevel;
	int Scene_WaterWaveDetail;
	float Water_WaveHeight;
	float Water_TessellationLevel;
	float Material_EmissionBrightness;
	int Lighting_BlockTemp;
	float Lighting_PenumbraSize;
	float Scene_EffectBloomStrength;
	float Scene_PostExposureMin;
	float Scene_PostExposureMax;
	float Scene_PostExposureRange;
	float Scene_PostExposureSpeed;
	float Post_Tonemap_Contrast;
	float Post_Tonemap_LinearStart;
	float Post_Tonemap_LinearLength;
	float Post_Tonemap_Black;
};
