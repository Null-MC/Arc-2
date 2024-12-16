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

out VertexData2 {
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 localPos;
	vec3 localOffset;
	vec3 localNormal;
	vec4 localTangent;
	flat int material;
} vOut;

#include "/settings.glsl"
#include "/lib/common.glsl"

#ifdef RENDER_TRANSLUCENT
	#include "/lib/water_waves.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	vOut.localPos = mul3(playerModelViewInverse, viewPos);
	// vOut.surfacePos = vOut.localPos;
	vOut.localOffset = vec3(0.0);

	#if defined RENDER_TRANSLUCENT && defined WATER_WAVES_ENABLED && !defined WATER_TESSELLATION_ENABLED
        bool isWater = bitfieldExtract(blockMask, 6, 1) != 0;

        if (isWater) {
			const float lmcoord_y = 1.0;

            vec3 waveOffset = GetWaveHeight(vOut.localPos + cameraPos, lmcoord_y, timeCounter, WaterWaveOctaveMin);
            vOut.localOffset.y += waveOffset.y;

            vOut.localPos += vOut.localOffset;
			viewPos = mul3(playerModelView, vOut.localPos);
        }
	#endif

    data.clipPos = iris_projectionMatrix * vec4(viewPos, 1.0);

    #ifdef EFFECT_TAA_ENABLED
        jitter(data.clipPos);
    #endif
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;
    vOut.light = data.light;
    vOut.color = data.color;

	vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
	vOut.localNormal = mat3(playerModelViewInverse) * viewNormal;

    vec3 viewTangent = mat3(iris_modelViewMatrix) * data.tangent.xyz;
    vOut.localTangent.xyz = mat3(playerModelViewInverse) * viewTangent;
    vOut.localTangent.w = data.tangent.w;

    vOut.material = blockMask;
}
