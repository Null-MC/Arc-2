#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
	vec2 uv;
} vOut;

#include "/lib/common.glsl"

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	data.clipPos = iris_projectionMatrix * vec4(viewPos, 1.0);

    #ifdef EFFECT_TAA_ENABLED
        jitter(data.clipPos);
    #endif
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;
}
