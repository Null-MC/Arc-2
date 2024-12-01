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
out vec3 localOffset;
out vec3 localNormal;
out vec3 shadowViewPos;
flat out int material;

#include "/settings.glsl"
#include "/lib/common.glsl"

#ifdef RENDER_TRANSLUCENT
	#include "/lib/water_waves.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	localPos = mul3(playerModelViewInverse, viewPos);
	localOffset = vec3(0.0);

	#ifdef RENDER_TRANSLUCENT
        bool isWater = bitfieldExtract(blockMask, 6, 1) != 0;

        if (isWater) {
			const float lmcoord_y = 1.0;

            vec3 waveOffset = GetWaveHeight(localPos + cameraPos, lmcoord_y, timeCounter, 12);
            localOffset.y += waveOffset.y;

            localPos += localOffset;
			viewPos = mul3(playerModelView, localPos);
        }
	#endif

	shadowViewPos = mul3(shadowModelView, localPos);

	vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
	localNormal = mat3(playerModelViewInverse) * viewNormal;

    data.clipPos = iris_projectionMatrix * vec4(viewPos, 1.0);
}

void iris_sendParameters(in VertexData data) {
    uv = data.uv;
    light = data.light;
    color = data.color;

    material = blockMask;
    // emission = (blockMask & 8) != 0;
}
