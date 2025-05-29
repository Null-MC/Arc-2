#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 localPos;
	vec3 shadowViewPos;
} vOut;

#include "/lib/common.glsl"

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	vOut.localPos = mul3(ap.camera.viewInv, viewPos);

    data.clipPos = iris_projectionMatrix * vec4(viewPos, 1.0);

    #ifdef EFFECT_TAA_ENABLED
        jitter(data.clipPos);
    #endif
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;
    vOut.light = data.light;
    vOut.color = data.color;

    #ifdef SHADOWS_ENABLED
        vOut.shadowViewPos = mul3(ap.celestial.view, vOut.localPos);
    #endif
}
