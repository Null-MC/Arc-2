#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

// layout(location = 6) in int blockMask;

out VertexData2 {
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 localPos;
	vec3 localOffset;
	vec3 localNormal;
	vec4 localTangent;
	flat uint blockId;

	#ifdef RENDER_PARALLAX
		vec3 tangentViewPos;
		flat vec2 atlasMinCoord;
		flat vec2 atlasMaxCoord;
	#endif
} vOut;

#include "/lib/common.glsl"

#ifdef RENDER_TRANSLUCENT
	#include "/lib/water_waves.glsl"
#endif

#ifdef RENDER_PARALLAX
	#include "/lib/utility/tbn.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	vOut.localPos = mul3(playerModelViewInverse, viewPos);
	vOut.localOffset = vec3(0.0);

	#if defined RENDER_TRANSLUCENT && defined WATER_WAVES_ENABLED && !defined WATER_TESSELLATION_ENABLED
        // bool isWater = bitfieldExtract(blockMask, 6, 1) != 0;
	    bool is_fluid = iris_hasFluid(vIn.blockId);

        if (is_fluid) {
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
    vOut.blockId = data.blockId;

	vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
	vOut.localNormal = mat3(playerModelViewInverse) * viewNormal;

    vec3 viewTangent = mat3(iris_modelViewMatrix) * data.tangent.xyz;
    vOut.localTangent.xyz = mat3(playerModelViewInverse) * viewTangent;
    vOut.localTangent.w = data.tangent.w;

	#ifdef RENDER_PARALLAX
		vOut.atlasMinCoord = iris_getTexture(data.textureId).minCoord;
		vOut.atlasMaxCoord = iris_getTexture(data.textureId).maxCoord;

		mat3 matViewTBN = GetTBN(viewNormal, viewTangent, data.tangent.w);

		vec3 viewPos = mul3(playerModelView, vOut.localPos);
		vOut.tangentViewPos = viewPos.xyz * matViewTBN;

//		#ifdef WORLD_SHADOW_ENABLED
//			vOut.lightPos_T = shadowLightPosition * matViewTBN;
//		#endif
	#endif
}
