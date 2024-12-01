#version 430 core

/*

VertexData is a predefined struct. You do not need to define it.
Your job in iris_emitVertex is to take the model space position, and convert it into clip space along with any vertex transformations you wish.

After this, mods get a chance to run their own transformations; and then you can use iris_sendParameters to send data to your fragment shader.


struct VertexData {
	vec4 pos;
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 normal;
	vec4 tangent;
	vec4 overlayColor;
};

*/

layout(location = 6) in int blockMask;

out vec2 uv;
out vec2 light;
out vec4 color;
out vec3 localPos;
out vec3 localNormal;
out vec3 shadowViewPos;
flat out int material;

#include "/settings.glsl"
#include "/lib/common.glsl"


void iris_emitVertex(inout VertexData data) {
	localPos = (playerModelViewInverse * (iris_modelViewMatrix * data.pos)).xyz;

	shadowViewPos = mul3(shadowModelView, localPos);

	localNormal = mat3(playerModelViewInverse) * (mat3(iris_modelViewMatrix) * data.normal);

    data.pos = iris_projectionMatrix * (iris_modelViewMatrix * data.pos);
}

void iris_sendParameters(in VertexData data) {
    uv = data.uv;
    light = data.light;
    color = data.color;

    material = blockMask;
    // emission = (blockMask & 8) != 0;
}
