#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

uniform sampler2D blockAtlas;
uniform sampler2D blockAtlasS;

uniform sampler2D texSkyIrradiance;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyView;
uniform sampler2D texBlueNoise;

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
	uniform samplerCubeArrayShadow pointLightFiltered;

	#ifdef LIGHTING_SHADOW_PCSS
		uniform samplerCubeArray pointLight;
	#endif
#endif

#ifdef FLOODFILL_ENABLED
	uniform sampler3D texFloodFill;
	uniform sampler3D texFloodFill_alt;
#endif

#ifdef SHADOWS_ENABLED
	uniform sampler2DArray shadowMap;
	uniform sampler2DArray solidShadowMap;
	uniform sampler2DArray texShadowBlocker;
	uniform sampler2DArray texShadowColor;
#endif

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
	uniform sampler3D texFogNoise;
#endif

#include "/lib/common.glsl"

#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/voxel-block-face.glsl"
#include "/lib/buffers/wsgi.glsl"

#ifndef VOXEL_PROVIDED
	#include "/lib/buffers/voxel-block.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
	#include "/lib/buffers/light-list.glsl"
#endif

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"

#include "/lib/sampling/erp.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/noise/blue.glsl"

#include "/lib/hg.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/irradiance.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/view.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/material/material.glsl"
#include "/lib/material/wetness.glsl"

#include "/lib/voxel/dda.glsl"
#include "/lib/voxel/wsgi-common.glsl"
#include "/lib/voxel/wsgi-sample.glsl"

#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"
#include "/lib/light/volumetric.glsl"

#ifdef SHADOWS_ENABLED
	#ifdef SHADOW_DISTORTION_ENABLED
		#include "/lib/shadow/distorted.glsl"
	#endif

	#include "/lib/shadow/csm.glsl"
	#include "/lib/shadow/sample.glsl"
#endif

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
	#include "/lib/sky/density.glsl"
	#include "/lib/sky/clouds.glsl"
	#include "/lib/shadow/clouds.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_MODE == LIGHT_MODE_SHADOWS
	#include "/lib/light/hcm.glsl"
	#include "/lib/material/material_fresnel.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
	#include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
	#include "/lib/shadow-point/common.glsl"
	#include "/lib/shadow-point/sample-common.glsl"
	#include "/lib/shadow-point/sample-geo.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_RT
	#include "/lib/voxel/light-trace.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_NONE
	#include "/lib/lightmap/sample.glsl"
#endif


ivec3 wsgi_getFrameOffset(const in float snapSize) {
	vec3 offset = floor(ap.temporal.pos / snapSize)	- floor(ap.camera.pos / snapSize);
	const int stepScale = 2;//int(exp2(WSGI_SNAP_SCALE - WSGI_VOXEL_SCALE));
    return ivec3(offset) * stepScale;
}

ivec3 wsgi_getVoxelOffset() {
	float voxelSize = wsgi_getVoxelSize(WSGI_VOXEL_SCALE);
	vec3 interval = wsgi_getStepInterval(ap.camera.pos, voxelSize*2.0);
	return VoxelBufferCenter - ivec3(WSGI_BufferCenter * voxelSize) - ivec3(floor(interval));
}

vec3 GetShadowSamplePos_LPV(const in vec3 shadowViewPos, out int cascadeIndex) {
	cascadeIndex = -1;
	vec3 shadowPos;

	for (int i = 0; i < SHADOW_CASCADE_COUNT; i++) {
		shadowPos = mul3(ap.celestial.projection[i], shadowViewPos).xyz;

		float blockPadding = exp2(i+1);

		vec2 cascadeSize = vec2(ap.celestial.projection[i][0].x, ap.celestial.projection[i][1].y);
		vec3 cascadePadding = vec3(blockPadding * cascadeSize, 0.0);

		if (clamp(shadowPos, -1.0 + cascadePadding, 1.0 - cascadePadding) == shadowPos) {
			cascadeIndex = i;
			break;
		}
	}

	return shadowPos * 0.5 + 0.5;
}

//float sphereContribution(const in vec3 normal, const in vec3 ray, const in float radius) {
//	//vec3  offset = sph.xyz - pos;
//	float dist   = length(ray);
//	float nl = dot(normal, ray/dist);
//	float h  = dist/radius;
//	float h2 = h*h;
//	//float k2 = 1.0 - h2*nl*nl;
//
//	return saturate(max(nl, 0.0) / h2);
//}

vec3 GetRandomFaceNormal(const in ivec3 cellPos, const in vec3 face_dir) {
	float seed_pos = hash13(cellPos);

//	vec2 noise_seed = cellPos.xz * vec2(71.0, 83.0) + cellPos.y * 67.0;
//	noise_seed += ap.time.frames * vec2(71.0, 83.0);
//	//vec3 noise_dir = sample_blueNoiseNorm(hash23(cellPos));
//
//	vec3 noise_dir = hash32(vec2(seed_pos * 123.45, ap.time.frames));
//	noise_dir = normalize(noise_dir * 2.0 - 1.0);
//
//	float faceF = dot(face_dir, noise_dir);
//	if (faceF < 0.0) {
//		noise_dir = -noise_dir;
//		faceF = -faceF;
//	}
//
//	noise_dir = noise_dir + face_dir;
//	return normalize(noise_dir);


	vec2 random = hash22(vec2(seed_pos * 123.456, ap.time.frames));

	float r = sqrt(random.x);
	float theta = 2.0 * PI * random.y;
	vec3 diskSample = r * vec3(cos(theta), sin(theta), 0.0);

	vec3 hemisphereSample = vec3(diskSample.xy, sqrt(max(1.0 - dot(diskSample.xy, diskSample.xy), 0.0)));

	vec3 normal = face_dir;
	vec3 tangent = abs(face_dir.y) > 0.5 ? vec3(0.0,0.0,1.0) : vec3(0.0,1.0,0.0);
	vec3 bitangent = normalize(cross(normal, tangent));
	vec3 worldSpaceSample = normal * hemisphereSample.z + tangent * hemisphereSample.x + bitangent * hemisphereSample.y;

	return worldSpaceSample;
}


vec3 trace_GI(const in vec3 traceOrigin, const in vec3 traceDir, const in int face_dir) {
	vec3 color = vec3(0.0);
	vec3 tracePos = traceOrigin;

	vec3 stepSizes, nextDist;
	dda_init(stepSizes, nextDist, tracePos, traceDir);

	bool hit = false;
	uint blockId = 0u;
	vec3 stepAxis = vec3(0.0); // todo: set initial?
	vec3 traceTint = vec3(1.0);
	ivec3 voxelPos = ivec3(traceOrigin);

	uint pathSamples = 0u;
	vec3 pathLight = vec3(0.0);
	bool altFrame = ap.time.frames % 2 == 1;

	// step out of initial voxel
//	#if WSGI_VOXEL_SCALE <= 1
//		vec3 stepAxisNext;
//		vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, traceDir);
//		stepAxis = stepAxisNext;
//		tracePos += step;
//	#endif

	int i = 0;
	for (; i < VOXEL_GI_MAXSTEP && !hit; i++) {
		vec3 stepAxisNext;
		vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, traceDir);

		voxelPos = ivec3(floor(fma(step, vec3(0.5), tracePos)));
		if (!voxel_isInBounds(voxelPos)) break;

		//voxelPos = ivec3(bufferPos * voxelSize) + wsgiVoxelOffset;
		blockId = SampleVoxelBlock(voxelPos);

		if (blockId > 0u) {
			if (iris_isFullBlock(blockId)) hit = true;

			uint blockTags = iris_blockInfo.blocks[blockId].z;
			const uint make_solid_tags = (1u << TAG_LEAVES) | (1u << TAG_STAIRS) | (1u << TAG_SLABS);
			if (iris_hasAnyTag(blockTags, make_solid_tags)) hit = true;
		}

		if (hit) break;

		vec3 localPos = voxel_getLocalPosition(voxelPos);
		vec3 bufferPos = wsgi_getBufferPosition(localPos, WSGI_CASCADE);
		//wsgi_bufferPos_n = ivec3(floor(wsgi_bufferPos)) + face_dir;
		if (wsgi_isInBounds(bufferPos)) {
			ivec3 wsgi_pos_n = ivec3(floor(bufferPos));
			pathLight = wsgi_sample_nearest(wsgi_pos_n, traceDir, WSGI_CASCADE);


//			int sampleVoxelI = wsgi_getBufferIndex(bufferPos, WSGI_CASCADE);
//
//			lpvShVoxel sampleVoxel;
//			if (altFrame) sampleVoxel = SH_LPV[sampleVoxelI];
//			else sampleVoxel = SH_LPV_alt[sampleVoxelI];
//
//			float face_counter;
//			pathLight += wsgi_sample_voxel_face(sampleVoxel.data[face_dir], shVoxel_dir[face_dir], traceDir, face_counter);
			pathSamples++;
		}

		tracePos += step;
		stepAxis = stepAxisNext;

		if (blockId > 0) {
			if (iris_hasTag(blockId, TAG_LEAVES)) traceTint *= 0.5;
			else if (iris_hasTag(blockId, TAG_TINTS_LIGHT)) {
				vec3 blockColor = iris_getLightColor(blockId).rgb;
				traceTint *= RgbToLinear(blockColor);
			}
			else if (iris_hasFluid(blockId))
				traceTint *= exp(-VL_WaterTransmit * VL_WaterDensity);

//				uint meta = iris_getMetadata(blockId);
//				uint blocking = bitfieldExtract(meta, 10, 4);
//				traceTint *= 1.0 - blocking/16.0;
		}
	}

	if (pathSamples > 0)
		pathLight = pathLight / pathSamples;

	pathLight *= 1000.0;

	float traceDist = max(distance(traceOrigin, tracePos), EPSILON);
	vec3 hit_localPos = voxel_getLocalPosition(tracePos);

	if (hit) {
		vec3 hitNormal = -sign(traceDir) * stepAxis;

		int blockFaceIndex = GetVoxelBlockFaceIndex(hitNormal);
		int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(voxelPos, blockFaceIndex);
		// TODO: if not set?!
		VoxelBlockFace blockFace = VoxelBlockFaceMap[blockFaceMapIndex];

		vec2 hitCoord;
		if (abs(hitNormal.y) > 0.5)      hitCoord = tracePos.xz;
		else if (abs(hitNormal.z) > 0.5) hitCoord = tracePos.xy;
		else                             hitCoord = tracePos.zy;

		hitCoord = 1.0 - fract(hitCoord);

		vec3 tex_tint = GetBlockFaceTint(blockFace.data);
		vec2 hit_lmcoord = GetBlockFaceLightMap(blockFace.data);
		//hit_lmcoord = _pow3(hit_lmcoord);

		iris_TextureInfo tex = iris_getTexture(blockFace.tex_id);
		vec2 hit_uv = fma(hitCoord, tex.maxCoord - tex.minCoord, tex.minCoord);

		vec4 hitColor = textureLod(blockAtlas, hit_uv, 2);
		//if (blockFace.tex_id == 0u) hitColor.rgb = vec3(1.0,0.0,0.0);

		vec3 albedo = RgbToLinear(hitColor.rgb * tex_tint);

		#if MATERIAL_FORMAT != MAT_NONE
			vec4 hit_specularData = textureLod(blockAtlasS, hit_uv, 0);

			//vec3 hit_localTexNormal = mat_normal(reflect_normalData);
			float hit_roughness = mat_roughness(hit_specularData.r);
			float hit_f0_metal = hit_specularData.g;
			float hit_porosity = mat_porosity(hit_specularData.b, hit_roughness, hit_f0_metal);
			float hit_emission = mat_emission(hit_specularData);
			float hit_sss = mat_sss(hit_specularData.b);
		#else
			//vec3 hit_localTexNormal = localGeoNormal;
			float hit_roughness = 0.92;
			float hit_f0_metal = 0.0;
			float hit_porosity = 1.0;
			float hit_sss = 0.0;

			float hit_emission = iris_getEmission(blockId) / 15.0;
		#endif

		float hit_roughL = _pow2(hit_roughness);
		//vec3 hit_localPos = voxel_getLocalPosition(tracePos);
		float hit_NoL = dot(-traceDir, hitNormal);

		float wetness = float(iris_hasFluid(blockId));

		float sky_wetness = smoothstep(0.9, 1.0, hit_lmcoord.y) * ap.world.rain;
		wetness = max(wetness, sky_wetness);

		#ifdef SHADOWS_ENABLED
			int hit_shadowCascade;
			vec3 hit_shadowViewPos = mul3(ap.celestial.view, hit_localPos);
			vec3 hit_shadowPos = GetShadowSamplePos_LPV(hit_shadowViewPos, hit_shadowCascade);
			hit_shadowPos.z -= GetShadowBias(hit_shadowCascade);

			float shadowWaterDepth = 0.0;
			vec3 hit_shadow = vec3(0.0);// vec3(Scene_SkyBrightnessSmooth);
			if (hit_shadowCascade >= 0)
				hit_shadow = SampleShadowColor(hit_shadowPos, hit_shadowCascade, shadowWaterDepth);

			// TODO: add a water mask to shadow buffers!
//			if (shadowWaterDepth > 0.0)
//				hit_shadow *= exp(-shadowWaterDepth * VL_WaterTransmit * VL_WaterDensity);
		#else
			float hit_shadow = 1.0;
		#endif

//		#ifdef WSGI_LEAK_FIX
//			hit_shadow *= smoothstep(0.0, 0.1, hit_lmcoord.y);
//		#endif

		float NoL_sun = dot(hitNormal, Scene_LocalSunDir);
		float NoL_moon = -NoL_sun;//dot(localTexNormal, -Scene_LocalSunDir);

		float skyLightF = smoothstep(0.0, 0.2, Scene_LocalLightDir.y);

		#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
			skyLightF *= SampleCloudShadows(hit_localPos);
		#endif

		vec3 hit_sunTransmit, hit_moonTransmit;
		GetSkyLightTransmission(hit_localPos, hit_sunTransmit, hit_moonTransmit);
		vec3 skyLight = SUN_LUX  * hit_sunTransmit  * max(NoL_sun, 0.0) * Scene_SunColor
					  + MOON_LUX * hit_moonTransmit * max(NoL_moon, 0.0);

//		#if defined(VL_SELF_SHADOW) && defined(SKY_CLOUDS_ENABLED)
//			vec2 dither_seed = gl_GlobalInvocationID.xz + gl_GlobalInvocationID.y*3;
//			#ifdef EFFECT_TAA_ENABLED
//				float shadow_dither = InterleavedGradientNoiseTime(dither_seed);
//			#else
//				float shadow_dither = InterleavedGradientNoise(dither_seed);
//			#endif
//
//			float shadowStepDist = 1.0;
//			float shadowDensity = 0.0;
//			for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
//				vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + hit_localPos;
//
//				float shadowSampleDensity = VL_WaterDensity;
//				if (ap.camera.fluid != 1) {
//					shadowSampleDensity = GetSkyDensity(fogShadow_localPos);
//
//					#ifdef SKY_FOG_NOISE
//						shadowSampleDensity += SampleFogNoise(fogShadow_localPos);
//					#endif
//				}
//
//				shadowDensity += shadowSampleDensity * shadowStepDist;// * (1.0 - max(1.0 - ii, 0.0));
//				shadowStepDist *= 2.0;
//			}
//
//			if (shadowDensity > 0.0)
//				skyLightF *= exp(-VL_ShadowTransmit * shadowDensity);
//		#endif

		//float hit_NoLm = max(dot(hitNormal, Scene_LocalLightDir), 0.0);

		vec3 hit_diffuse = skyLight * skyLightF * hit_shadow;
		//hit_diffuse *= hit_NoLm; //SampleLightDiffuse(hit_NoVm, hit_NoLm, hit_LoHm, hit_roughL);

		#ifdef LIGHTING_GI_SKYLIGHT
			vec3 hit_bufferPos = wsgi_getBufferPosition(hit_localPos, WSGI_VOXEL_SCALE);
			ivec3 hit_bufferPos_n = ivec3(floor(hit_bufferPos));

			hit_diffuse += wsgi_sample_nearest(hit_bufferPos_n, hitNormal, WSGI_CASCADE) * 1000.0;

			//hit_diffuse += 0.0016;
		#else
			//hit_diffuse += SampleSkyIrradiance(hitNormal, hit_lmcoord.y);
		#endif

		vec3 hit_voxelPos = voxelPos; //tracePos * voxelSize + wsgiVoxelOffset;

		#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
			vec3 specular;
			sample_AllPointLights(hit_diffuse, specular, hit_localPos, hitNormal, hitNormal, albedo, hit_f0_metal, hit_roughL, hit_sss);
		#elif LIGHTING_MODE == LIGHT_MODE_RT //&& defined(FALSE)
			// TODO: pick a random light and sample it?
			ivec3 lightBinPos = ivec3(floor(hit_voxelPos / LIGHT_BIN_SIZE));
			int lightBinIndex = GetLightBinIndex(lightBinPos);
			uint binLightCount = LightBinMap[lightBinIndex].lightCount;

			vec3 voxelPos_out = hit_voxelPos + 0.16*hitNormal;

			//vec3 jitter = vec3(0.0);//hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;

//				#if RT_MAX_SAMPLE_COUNT > 0
//					uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
//					float bright_scale = ceil(binLightCount / float(RT_MAX_SAMPLE_COUNT));
//				#else
				//uint maxSampleCount = binLightCount;
				const float bright_scale = 1.0; // TODO: why isn't this 1.0?
//				#endif

			int i_offset = int(binLightCount * hash13(vec3(gl_GlobalInvocationID.xy, ap.time.frames)));

			//for (int i = 0; i < maxSampleCount; i++) {
			if (binLightCount > 0) {
				int light_i = 0;
				int i2 = (light_i + i_offset) % int(binLightCount);

				uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2].voxelIndex;

				vec3 light_voxelPos = GetLightVoxelPos(light_voxelIndex) + 0.5;
				//light_voxelPos += jitter*0.125;

				vec3 light_LocalPos = voxel_getLocalPosition(light_voxelPos);

				uint blockId = SampleVoxelBlock(light_voxelPos);

				float lightRange = iris_getEmission(blockId);
				vec3 lightColor = iris_getLightColor(blockId).rgb;
				lightColor = RgbToLinear(lightColor);

				lightColor *= (lightRange/15.0) * BLOCK_LUX;

				vec3 lightVec = light_LocalPos - hit_localPos;
				float lightAtt = GetLightAttenuation(lightVec, lightRange);

				vec3 lightDir = normalize(lightVec);

				vec3 H = normalize(lightDir + -traceDir);

				float LoHm = max(dot(lightDir, H), 0.0);
				float NoLm = max(dot(hitNormal, lightDir), 0.0);
				//                    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

				//if (NoLm > 0.0 && dot(hitNormal, lightDir) > 0.0) {
					float NoVm = max(dot(hitNormal, -traceDir), 0.0);
					float NoHm = max(dot(hitNormal, H), 0.0);
					float VoHm = max(dot(-traceDir, H), 0.0);

					const bool hit_isUnderWater = false;
					vec3 F = material_fresnel(albedo, hit_f0_metal, hit_roughL, VoHm, hit_isUnderWater);
					vec3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, hit_roughL) * (1.0 - F);
					vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, hit_roughL);

					vec3 lightFinal = NoLm * lightColor * lightAtt;
					vec3 sampleDiffuse = D * lightFinal;
					vec3 sampleSpecular = S * lightFinal;

					vec3 traceStart = light_voxelPos;
					vec3 traceEnd = voxelPos_out;
					float traceRange = lightRange;
					bool traceSelf = !iris_isFullBlock(blockId);

					vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

					hit_diffuse += sampleDiffuse * shadow_color * bright_scale * 3.0;
					//hit_specular += sampleSpecular * shadow_color * bright_scale;
				//}
			}
		#elif LIGHTING_MODE == LIGHT_MODE_VANILLA
			const float occlusion = 1.0;
			hit_diffuse += GetVanillaBlockLight(hit_lmcoord.x, occlusion);
		#endif

		#ifdef FLOODFILL_ENABLED
			vec3 lpv_voxelPos = hit_voxelPos + 0.5*hitNormal;

			if (voxel_isInBounds(lpv_voxelPos)) {
				vec3 texcoord = lpv_voxelPos / VoxelBufferSize;
				bool altFrame = ap.time.frames % 2 == 1;

				vec3 lpv_light = altFrame
					? textureLod(texFloodFill, texcoord, 0).rgb
					: textureLod(texFloodFill_alt, texcoord, 0).rgb;

				hit_diffuse += lpv_light * BLOCK_LUX;
			}
		#endif

		float hit_metalness = mat_metalness(hit_f0_metal);
		hit_diffuse *= 1.0 - hit_metalness * (1.0 - hit_roughL);

		#if MATERIAL_EMISSION_POWER != 1
			hit_diffuse += pow(hit_emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness * BLOCK_LUX;
		#else
			hit_diffuse += hit_emission * Material_EmissionBrightness * BLOCK_LUX;
		#endif

		ApplyWetness_albedo(albedo, hit_porosity, wetness);

		color = albedo * hit_diffuse * max(hit_NoL, 0.0);

		// apply attenuation
		//color *= GetLightAttenuation(traceDist);
		//color *= 1.0 - 1.0/(1.0 + _pow2(traceDist));

//		const float radius = 0.5;
//		vec3 ray = tracePos - traceOrigin;
//		float sampleWeight = PI * sphereContribution(hitNormal, -ray, radius);
//		color *= sampleWeight;

		//color = mix(color, pathLight, saturate(float(i) / VOXEL_GI_MAXSTEP));
	}
	else {
		#if WSGI_CASCADE < (WSGI_CASCADE_COUNT-1)
			vec3 localPos = voxel_getLocalPosition(tracePos);
			vec3 wsgi_pos = wsgi_getBufferPosition(localPos, WSGI_VOXEL_SCALE+1);
			ivec3 wsgi_pos_n = ivec3(floor(wsgi_pos));

			color = wsgi_sample_nearest(wsgi_pos_n, traceDir, WSGI_CASCADE+1) * 1000.0;
			//color *= 1.0 - 1.0/(1.0 + _pow2(traceDist));
			//color *= GetLightAttenuation(traceDist);
		#else
			#ifdef LIGHTING_GI_SKYLIGHT
				for (int i2 = i; i2 < 32 && !hit; i2++) {
					vec3 stepAxisNext;
					vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, traceDir);

					voxelPos = ivec3(floor(fma(step, vec3(0.5), tracePos)));
					if (!voxel_isInBounds(voxelPos)) break;

					blockId = SampleVoxelBlock(voxelPos);

					if (blockId > 0u) {
						if (iris_isFullBlock(blockId)) {
							hit = true;
							break;
						}
						else if (iris_hasTag(blockId, TAG_LEAVES)) {
							traceTint *= 0.5;
						}
						else if (iris_hasFluid(blockId)) {
							traceTint *= exp(-VL_WaterTransmit * VL_WaterDensity);
						}
					}

					tracePos += step;
					stepAxis = stepAxisNext;
				}

				if (hit) {
					color = pathLight;
				}
				else {
					color = SampleSkyIrradiance(traceDir, 1.0);
				}
			#else
				color = pathLight;
			#endif
		#endif
	}

	return color * traceTint;
}


void main() {
	ivec3 bufferPos = ivec3(gl_GlobalInvocationID);
	//if (any(greaterThanEqual(bufferPos, WSGI_BufferSize))) return;

	bool altFrame = ap.time.frames % 2 == 1;

	float voxelSize = wsgi_getVoxelSize(WSGI_VOXEL_SCALE);
	ivec3 wsgi_bufferOffset = wsgi_getFrameOffset(voxelSize*2.0);
	ivec3 wsgiVoxelOffset = wsgi_getVoxelOffset();

	vec3 voxelPos = (bufferPos+0.5) * voxelSize + wsgiVoxelOffset;
	uint blockId = SampleVoxelBlock(voxelPos);

	bool isFullBlock = false;

	#if WSGI_VOXEL_SCALE <= 1
		if (blockId > 0u) {
			isFullBlock = iris_isFullBlock(blockId);
		}
	#endif

	lpvShVoxel voxel_gi = voxel_empty;

	if (!isFullBlock) {
		ivec3 cellIndex_prev = bufferPos - wsgi_bufferOffset;
		if (wsgi_isInBounds(cellIndex_prev)) {
			int i_prev = wsgi_getBufferIndex(cellIndex_prev, WSGI_CASCADE);

			if (altFrame) voxel_gi = SH_LPV[i_prev];
			else voxel_gi = SH_LPV_alt[i_prev];
		}
		#if WSGI_CASCADE < (WSGI_CASCADE_COUNT-1)
			// get previous value from parent if OOB
			else {
				vec3 localPos_prev = wsgi_getLocalPosition(bufferPos + 0.5, WSGI_VOXEL_SCALE);
				vec3 wsgi_pos_prev = wsgi_getBufferPosition(localPos_prev, WSGI_VOXEL_SCALE+1);
				ivec3 wsgi_pos_prev_n = ivec3(floor(wsgi_pos_prev));

				int i_prev = wsgi_getBufferIndex(wsgi_pos_prev_n, WSGI_CASCADE+1);

				if (altFrame) voxel_gi = SH_LPV[i_prev];
				else voxel_gi = SH_LPV_alt[i_prev];
			}
		#endif

		//float seed_pos = hash13(bufferPos);

		for (int dir = 0; dir < 6; dir++) {
			vec3 face_color;
			float face_counter;
			decode_shVoxel_dir(voxel_gi.data[dir], face_color, face_counter);

			vec3 noise_dir = GetRandomFaceNormal(bufferPos, shVoxel_dir[dir]);

			float faceF = dot(shVoxel_dir[dir], noise_dir);

			//vec3 noise_offset = sample_blueNoise(hash23(bufferPos));
//			vec3 noise_offset = hash33(bufferPos + ap.time.frames);
//			noise_offset = noise_offset - 0.5;

			//float traceDist;

			// TODO: step out of intitial wsgi voxel
			vec3 tracePos = voxelPos;
			#if WSGI_VOXEL_SCALE > 1
				vec3 offsetBufferPos = bufferPos+0.5;// + noise_offset;

				vec3 stepSizes, nextDist;
				dda_init(stepSizes, nextDist, offsetBufferPos, noise_dir);

				vec3 stepAxisNext;
				vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, noise_dir);
				//stepAxis = stepAxisNext;
				offsetBufferPos += step;

				vec3 traceLocalPos = wsgi_getLocalPosition(offsetBufferPos, WSGI_CASCADE);
				tracePos = voxel_GetBufferPosition(traceLocalPos);

				tracePos += 0.05 * noise_dir;
				//tracePos = offsetBufferPos * voxelSize + wsgiVoxelOffset + 0.05 * noise_dir;
			#endif

			vec3 traceSample = trace_GI(tracePos, noise_dir, dir);

//			if (iris_hasFluid(blockId)) {
//				traceSample *= exp(-3.0 * VL_WaterTransmit * VL_WaterDensity);
//			}

//			const float radius = 0.5;
//			float sampleWeight = PI * sphereContribution(shVoxel_dir[dir], noise_dir * traceDist, radius);
			float sampleWeight = max(faceF, 0.0);// / (3.0 + traceDist);

			face_counter = clamp(face_counter + sampleWeight, 0.0, VOXEL_GI_MAXFRAMES);

			traceSample = clamp(traceSample * 0.001, 0.0, 65000.0);

			float mixF = 1.0 / (1.0 + face_counter);
			face_color = mix(face_color, traceSample, mixF * sampleWeight);// * max(faceF, 0.0);

			voxel_gi.data[dir] = encode_shVoxel_dir(face_color, face_counter);
		}
	}

	int writeIndex = wsgi_getBufferIndex(bufferPos, WSGI_CASCADE);

	if (altFrame) SH_LPV_alt[writeIndex] = voxel_gi;
	else SH_LPV[writeIndex] = voxel_gi;
}
