#define FOG_CAVE_DENSITY 0.18

#define FOG_NIGHT_MUL 6.0

#define MATERIAL_EMISSION_POWER 1
#define MATERIAL_ROUGH_REFRACT
#define MATERIAL_PARALLAX_MAXDIST 48
#define MATERIAL_PARALLAX_OPTIMIZE

//#define REFRACTION_SNELL

#define SHADOW_VOXEL_TEST

#define HANDLIGHT_TRACE

//#define VL_SOFT_SHADOW
//#define VL_SELF_SHADOW
#define VL_STEP_POW 100

#define POINT_LIGHT_POM

#define VOXEL_SHADOW_CASCADE 0

//#define VOXEL_SKIP_EMPTY
//#define VOXEL_SKIP_SECTIONS

//#define TRANSLUCENT_DEPTH_TEST_FIX

#define MC_HAND_DEPTH 0.125 // [0.0625 0.125 0.25]


const float ATMOSPHERE_MAX = 4200.0;

const float SUN_SIZE = 1.2;
const float SUN_LUMINANCE = 1000000;//1.6e9;
const float SUN_LUX = 130000.0;

const float MOON_SIZE = 3.4;
const float MOON_LUMINANCE = 80.00;
const float MOON_LUX = 12.0;

const float STAR_LUMINANCE = 32.00;

const float BLOCKLIGHT_LUMINANCE = 32000.0;
const float BLOCK_LUX = 24000.0;

const float SKY_AMBIENT = 1.0;

const int SHADOW_PCF_SAMPLES = 8;
const int SHADOW_PCSS_SAMPLES = 6;
const float SHADOW_PENUMBRA_SCALE = 64.0;
const float Shadow_MaxPcfSize = 0.6;

const int SHADOW_SCREEN_STEPS = 12;
const float ShadowScreenSlope = 0.85;

const float WaterTintMinDist = 0.0;
const float cloudHeight = 320.0;

const vec3 WhiteWorld_Value = vec3(0.8);


// DO NOT EDIT
const float shadowMapResolution = float(SHADOW_RESOLUTION);
const float shadowPixelSize = 1.0 / shadowMapResolution;

const int VL_maxSamples_near = 32;
const int VL_maxSamples_far = 16;

#if defined MATERIAL_PARALLAX_ENABLED && defined RENDER_TERRAIN && MATERIAL_FORMAT != MAT_NONE
	#define RENDER_PARALLAX
#endif

#if defined(POINT_LIGHT_POM) && defined(MATERIAL_PARALLAX_ENABLED) && defined(MATERIAL_PARALLAX_DEPTHWRITE)
	#define IS_POINT_LIGHT_POM_ENABLED
#endif

#ifdef UBO_SCENE_SETTINGS
	layout (std140, binding = UBO_SCENE_SETTINGS) uniform SceneSettings {
		int Sky_SunTemp;
		float Sky_sunPathRotation;
		float Sky_CloudCoverage;
		float Scene_SkyFogDensityF;
		float Scene_SkyFogSeaLevel;
		int Scene_WaterWaveDetail;
		float Water_WaveHeight;
		float Water_TessellationLevel;
		float Material_EmissionBrightness;
		int Lighting_BlockTemp;
		float Lighting_PenumbraSize;
		float Effect_SSAO_Strength;
		float Effect_Bloom_Strength;
		float Effect_DOF_Radius;
		float Scene_PostExposureMin;
		float Scene_PostExposureMax;
		float Scene_PostExposureSpeed;
		float Post_ExposureOffset;
		float Post_Tonemap_Contrast;
		float Post_Tonemap_LinearStart;
		float Post_Tonemap_LinearLength;
		float Post_Tonemap_Black;
	};
#endif
