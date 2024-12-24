#version 430 core
#extension GL_NV_gpu_shader5: enable

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#ifdef RT_ENABLED
	#include "/lib/buffers/light-list.glsl"
    #include "/lib/buffers/triangle-list.glsl"
#endif


void main() {
	Scene_LocalSunDir = normalize(mat3(playerModelViewInverse) * sunPosition);
	Scene_LocalLightDir = normalize(mat3(playerModelViewInverse) * shadowLightPosition);

	#ifdef RT_ENABLED
		Scene_LightCount = 0u;
		Scene_TriangleCount = 0u;
	#endif

	if (!guiHidden) {
		Scene_TrackPos = cameraPos;
	}
}
