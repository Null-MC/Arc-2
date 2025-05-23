#version 430 core

out VertexData2 {
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 localPos;
	vec3 shadowViewPos;
} vOut;

#include "/settings.glsl"
#include "/lib/common.glsl"

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	vOut.localPos = mul3(ap.camera.viewInv, viewPos);

    #ifdef THIS_DOESNT_WORK
        // extend the particle planes outward
        // won't work cause designed to fit world
        vOut.localPos.xz = vOut.localPos.xz * 4.0;
        viewPos = mul3(ap.camera.view, vOut.localPos);
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

    #ifdef SHADOWS_ENABLED
        vOut.shadowViewPos = mul3(ap.celestial.view, vOut.localPos);
    #endif
}
