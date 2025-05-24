#version 430 core

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"


void main() {
	Scene_SkyBrightnessSmooth = 0.0;
	Scene_AvgExposure = 0.85;
	Scene_FocusDepth = 60.0;
}
