#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT
	#include "/lib/buffers/light-list.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/quad-list.glsl"
#endif


void main() {
	Scene_LocalSunDir = normalize(mat3(ap.camera.viewInv) * ap.celestial.sunPos);
	Scene_LocalLightDir = normalize(mat3(ap.camera.viewInv) * ap.celestial.pos);

	// TODO: smooth center-depth
	//Scene_FocusDepth = Scene_FocusDepth;

	#if LIGHTING_MODE == LIGHT_MODE_RT
		Scene_LightCount = 0u;
	#endif

	#ifdef VOXEL_TRI_ENABLED
		SceneQuads.total = 0u;
	#endif

	if (!ap.game.guiHidden) {
		Scene_TrackPos = ap.camera.pos;
	}
}
