#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

uniform sampler2D solidDepthTex;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/sampling/depth.glsl"
#include "/lib/utility/blackbody.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT || defined(DEBUG_LIGHT_COUNT)
	#include "/lib/buffers/light-list.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/quad-list.glsl"
#endif


void main() {
	#ifdef WORLD_END
		Scene_SunColor = vec3(0.0);
		Scene_MoonColor = blackbody(3800.0);
	#elif defined (WORLD_SKY_ENABLED)
		Scene_SunColor = blackbody(Sky_SunTemp);
		// fix for UBO having no/bad data first frame
		if (Sky_SunTemp < EPSILON) Scene_SunColor = vec3(0.0);

		Scene_MoonColor = Scene_SunColor;
	#endif

	Scene_LocalSunDir = normalize(mat3(ap.camera.viewInv) * ap.celestial.sunPos);
	Scene_LocalLightDir = normalize(mat3(ap.camera.viewInv) * ap.celestial.pos);

	float depthTimeF = 1.0 - exp(-max(EFFECT_DOF_SPEED * ap.time.delta, 1.0e-12));
	float centerDepthL = textureLod(solidDepthTex, vec2(0.5), 0).r;
	centerDepthL = linearizeDepth(centerDepthL, ap.camera.near, ap.camera.far);
	Scene_FocusDepth += (centerDepthL - Scene_FocusDepth) * depthTimeF;

	#if defined(LIGHT_LIST_ENABLED) && defined(DEBUG_LIGHT_COUNT)
		Scene_LightCount = 0u;

		#ifndef LIGHTING_SHADOW_BIN_ENABLED
			// manually count from uniform
			for (int i = 0; i < LIGHTING_SHADOW_MAX_COUNT; i++) {
				ap_PointLight light = iris_getPointLight(i);
				if (light.block >= 0) Scene_LightCount++;
			}
		#endif
	#endif

	#ifdef VOXEL_TRI_ENABLED
		SceneQuads.total = 0u;
	#endif

	if (!ap.game.guiHidden) {
		Scene_TrackPos = ap.camera.pos;
	}
}
