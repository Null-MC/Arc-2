#version 430 core
#extension GL_NV_gpu_shader5: enable

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT
	#include "/lib/buffers/light-list.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/triangle-list.glsl"
#endif


void main() {
	Scene_LocalSunDir = normalize(mat3(playerModelViewInverse) * sunPosition);
	Scene_LocalLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);

	#if LIGHTING_MODE == LIGHT_MODE_RT
		Scene_LightCount = 0u;
	#endif

	#ifdef VOXEL_TRI_ENABLED
		Scene_TriangleCount = 0u;
	#endif

	if (!guiHidden) {
		Scene_TrackPos = cameraPos;
	}
}
