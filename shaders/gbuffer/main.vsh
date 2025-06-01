#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

// layout(location = 6) in int blockMask;

#if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
	uniform sampler3D texFogNoise;
#endif

out VertexData2 {
	vec2 uv;
	vec2 light;
	vec4 color;
	vec3 localPos;
	vec3 localOffset;
	vec3 localNormal;
	vec4 localTangent;
	flat uint blockId;

	#ifdef RENDER_ENTITY
		vec4 overlayColor;
	#endif

	#if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
		#ifndef WATER_TESSELLATION_ENABLED
			vec3 surfacePos;
		#endif

		float waveStrength;
	#endif

	#if defined(RENDER_PARALLAX) || defined(MATERIAL_NORMAL_SMOOTH)
		vec3 tangentViewPos;
		flat vec2 atlasCoordMin;
		flat vec2 atlasCoordSize;
	#endif
} vOut;

#include "/lib/common.glsl"

#ifdef RENDER_TERRAIN
	#ifdef RENDER_TRANSLUCENT
		#include "/lib/water_waves.glsl"
	#endif

	#include "/lib/wind_waves.glsl"
#endif

#ifdef RENDER_PARALLAX
	#include "/lib/utility/tbn.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
	#include "/lib/taa_jitter.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
	vec3 viewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);
	vOut.localPos = mul3(ap.camera.viewInv, viewPos);
	vOut.localOffset = vec3(0.0);

	#ifdef RENDER_TERRAIN
		#if defined(RENDER_TRANSLUCENT) && defined(WATER_WAVES_ENABLED)
			vec3 worldPos = vOut.localPos + ap.camera.pos;

			const vec3 windDir1 = vec3(0.01,  0.01, 0.02);
			const vec3 windDir2 = vec3(0.04, -0.01, 0.02);

			vec3 uvWave = 0.004 * worldPos + windDir1 * ap.time.elapsed;
			float waveNoise1 = 1.0 - textureLod(texFogNoise, uvWave, 0).r;
			uvWave = 0.008 * worldPos + windDir2 * ap.time.elapsed;
			float waveNoise2 = 1.0 - textureLod(texFogNoise, uvWave, 0).r;
			float waveNoise = waveNoise1 * waveNoise2;

			vOut.waveStrength = 1.0;//waveNoise * 0.9 + 0.1;

			#ifndef WATER_TESSELLATION_ENABLED
				// bool isWater = bitfieldExtract(blockMask, 6, 1) != 0;
				bool is_fluid = iris_hasFluid(data.blockId);
				vOut.surfacePos = vOut.localPos;

				if (is_fluid) {
					const float lmcoord_y = 1.0;

					vec3 waveOffset = GetWaveHeight(vOut.localPos + ap.camera.pos, lmcoord_y, ap.time.elapsed, WaterWaveOctaveMin);
					vOut.localOffset.y += waveOffset.y * vOut.waveStrength;

					vOut.localPos.y += vOut.localOffset.y;
					viewPos = mul3(ap.camera.view, vOut.localPos);
				}
			#endif
		#endif

		#ifdef WIND_WAVING_ENABLED
			ApplyWavingOffset(vOut.localPos, data.blockId);
			viewPos = mul3(ap.camera.view, vOut.localPos);
		#endif
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

	#ifdef RENDER_ENTITY
		vOut.overlayColor = data.overlayColor;
	#endif

	//vOut.light = saturate(unmix(vOut.light, (0.5/16.0), (15.5/16.0)));

	vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
	vOut.localNormal = mat3(ap.camera.viewInv) * viewNormal;

	vec3 viewTangent = mat3(iris_modelViewMatrix) * data.tangent.xyz;
	vOut.localTangent.xyz = mat3(ap.camera.viewInv) * viewTangent;
	vOut.localTangent.w = data.tangent.w;

	#if defined(RENDER_PARALLAX) || defined(MATERIAL_NORMAL_SMOOTH)
		// TODO: These are wrong! replace with old midcoord derived version
		vOut.atlasCoordMin = iris_getTexture(data.textureId).minCoord;
		vOut.atlasCoordSize = iris_getTexture(data.textureId).maxCoord - vOut.atlasCoordMin;

		#ifdef RENDER_PARALLAX
			mat3 matViewTBN = GetTBN(viewNormal, viewTangent, data.tangent.w);

			vec3 viewPos = mul3(ap.camera.view, vOut.localPos);
			vOut.tangentViewPos = viewPos.xyz * matViewTBN;

	//		#ifdef WORLD_SHADOW_ENABLED
	//			vOut.lightPos_T = shadowLightPosition * matViewTBN;
	//		#endif
		#endif
	#endif
}
