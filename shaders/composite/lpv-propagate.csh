#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

shared uint sharedBlockMap[10*10*10];

#if LIGHTING_MODE == LIGHT_MODE_LPV
	shared uint sharedBlockMetaMap[10*10*10];
	shared vec3 floodfillBuffer[10*10*10];

	layout(rgba16f) uniform image3D imgFloodFill;
	layout(rgba16f) uniform image3D imgFloodFill_alt;
#endif

#ifdef VOXEL_GI_ENABLED
	uniform sampler2D blockAtlas;
	uniform sampler2D blockAtlasS;

	//uniform sampler2D texSkyIrradiance;
	uniform sampler2D texSkyTransmit;
	uniform sampler2D texSkyView;
	uniform sampler2D texBlueNoise;

	uniform sampler3D texFloodFill;
	uniform sampler3D texFloodFill_alt;

	uniform sampler2DArray shadowMap;
	uniform sampler2DArray solidShadowMap;
	uniform sampler2DArray texShadowColor;
#endif

#include "/lib/common.glsl"

#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/voxel-block.glsl"

#ifdef VOXEL_GI_ENABLED
	#include "/lib/buffers/sh-gi.glsl"
#endif

#include "/lib/voxel/voxel_common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_LPV
	#include "/lib/utility/hsv.glsl"
#endif

#ifdef VOXEL_GI_ENABLED
	#include "/lib/noise/hash.glsl"
	#include "/lib/noise/blue.glsl"

	#include "/lib/sky/common.glsl"
	#include "/lib/sky/transmittance.glsl"
	#include "/lib/sky/view.glsl"

	#include "/lib/utility/blackbody.glsl"
	#include "/lib/material/material.glsl"
	#include "/lib/voxel/dda.glsl"

	#include "/lib/lpv/sh-gi-sample.glsl"

	#ifdef SHADOWS_ENABLED
		#include "/lib/shadow/csm.glsl"
		#include "/lib/shadow/sample.glsl"
	#endif
#endif


const float LpvFalloff = 0.998;
const float LpvBlockRange = 1.0;
const ivec3 flattenShared = ivec3(1, 10, 100);

int getSharedCoord(ivec3 pos) {
	return sumOf(pos * flattenShared);
}

ivec3 GetVoxelFrameOffset() {
    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 posNow = GetVoxelCenter(ap.camera.pos, viewDir);

    vec3 viewDirPrev = vec3(ap.temporal.view[0].z, ap.temporal.view[1].z, ap.temporal.view[2].z);
    vec3 posPrev = GetVoxelCenter(ap.temporal.pos, viewDirPrev);

    vec3 posLast = posNow + (ap.temporal.pos - ap.camera.pos) - (posPrev - posNow);

    return ivec3(posNow) - ivec3(posLast);
}

#if LIGHTING_MODE == LIGHT_MODE_LPV
	vec3 sample_floodfill_prev(in ivec3 texCoord) {
		if (!IsInVoxelBounds(texCoord)) return vec3(0.0);

		bool altFrame = ap.time.frames % 2 == 1;

		vec3 lpvSample = altFrame
			? imageLoad(imgFloodFill, texCoord).rgb
			: imageLoad(imgFloodFill_alt, texCoord).rgb;

		vec3 hsv = RgbToHsv(lpvSample);
		hsv.z = pow(6.0, hsv.z * LpvBlockRange) - 1.0;
		lpvSample = HsvToRgb(hsv);

		return lpvSample;
	}
#endif

void populateShared(const in ivec3 voxelFrameOffset) {
	uint i1 = uint(gl_LocalInvocationIndex) * 2u;
	if (i1 >= 1000u) return;

	uint i2 = i1 + 1u;
	ivec3 workGroupOffset = ivec3(gl_WorkGroupID * gl_WorkGroupSize) - 1;

	ivec3 pos1 = workGroupOffset + ivec3(i1 / flattenShared) % 10;
	ivec3 pos2 = workGroupOffset + ivec3(i2 / flattenShared) % 10;

	#if LIGHTING_MODE == LIGHT_MODE_LPV
		ivec3 lpvPos_prev1 = pos1 + voxelFrameOffset;
		ivec3 lpvPos_prev2 = pos2 + voxelFrameOffset;

		floodfillBuffer[i1] = sample_floodfill_prev(lpvPos_prev1);
		floodfillBuffer[i2] = sample_floodfill_prev(lpvPos_prev2);
	#endif

	uint blockId1 = 0u;
	uint blockId2 = 0u;
	#if LIGHTING_MODE == LIGHT_MODE_LPV
		uint blockMeta1 = 0u;
		uint blockMeta2 = 0u;
	#endif

	if (IsInVoxelBounds(pos1)) {
		blockId1 = imageLoad(imgVoxelBlock, pos1).r;

		#if LIGHTING_MODE == LIGHT_MODE_LPV
			if (blockId1 > 0u)
				blockMeta1 = iris_getMetadata(blockId1);
		#endif
	}

	if (IsInVoxelBounds(pos2)) {
		blockId2 = imageLoad(imgVoxelBlock, pos2).r;

		#if LIGHTING_MODE == LIGHT_MODE_LPV
			if (blockId2 > 0u)
				blockMeta2 = iris_getMetadata(blockId2);
		#endif
	}

	sharedBlockMap[i1] = blockId1;
	sharedBlockMap[i2] = blockId2;

	#if LIGHTING_MODE == LIGHT_MODE_LPV
		sharedBlockMetaMap[i1] = blockMeta1;
		sharedBlockMetaMap[i2] = blockMeta2;
	#endif
}

#if LIGHTING_MODE == LIGHT_MODE_LPV
	vec3 sampleFloodfillShared(ivec3 pos, uint mask_index) {
		int shared_index = getSharedCoord(pos);
	//	uint blockMeta = sharedBlockMetaMap[shared_index];
	//	uint wMask = bitfieldExtract(blockMeta, int(mask_index), 1);
		return floodfillBuffer[shared_index];// * wMask;
	}

	vec3 mixNeighbours(const in ivec3 fragCoord, const in uint mask) {
		uvec3 m1 = 1u - (uvec3(mask) >> uvec3(BLOCK_FACE_WEST, BLOCK_FACE_UP, BLOCK_FACE_NORTH)) & uvec3(1u);
		uvec3 m2 = 1u - (uvec3(mask) >> uvec3(BLOCK_FACE_EAST, BLOCK_FACE_DOWN, BLOCK_FACE_SOUTH)) & uvec3(1u);

		vec3 nX1 = sampleFloodfillShared(fragCoord + ivec3(-1,  0,  0), BLOCK_FACE_EAST) * m1.x;
		vec3 nX2 = sampleFloodfillShared(fragCoord + ivec3( 1,  0,  0), BLOCK_FACE_WEST) * m2.x;
		vec3 nY1 = sampleFloodfillShared(fragCoord + ivec3( 0, -1,  0), BLOCK_FACE_DOWN) * m1.y;
		vec3 nY2 = sampleFloodfillShared(fragCoord + ivec3( 0,  1,  0), BLOCK_FACE_UP) * m2.y;
		vec3 nZ1 = sampleFloodfillShared(fragCoord + ivec3( 0,  0, -1), BLOCK_FACE_SOUTH) * m1.z;
		vec3 nZ2 = sampleFloodfillShared(fragCoord + ivec3( 0,  0,  1), BLOCK_FACE_NORTH) * m2.z;

		const float avgFalloff = (1.0/6.0) * LpvFalloff;
		return (nX1 + nX2 + nY1 + nY2 + nZ1 + nZ2) * avgFalloff;
	}
#endif

#ifdef VOXEL_GI_ENABLED
	vec3 trace_GI(const in vec3 traceOrigin, const in vec3 traceDir, const in int face_dir) {
//		vec3 color = vec3(1.0, 0.0, 1.0);
//		if      (traceDir.x >  0.5) color = vec3(0.0, 0.0, 1.0);
//		else if (traceDir.x < -0.5) color = vec3(0.0, 1.0, 1.0);
//		else if (traceDir.z >  0.5) color = vec3(0.0, 1.0, 0.0);
//		else if (traceDir.z < -0.5) color = vec3(1.0, 1.0, 0.0);
//		else if (traceDir.y >  0.5) color = vec3(1.0, 0.0, 0.0);

		vec3 color = vec3(0.0);
		vec3 tracePos = traceOrigin;

		vec3 stepSizes, nextDist;
		dda_init(stepSizes, nextDist, tracePos, traceDir);

		vec3 stepAxis = vec3(0.0); // todo: set initial?
		vec3 traceTint = vec3(1.0);
		bool hit = false;
		ivec3 voxelPos = ivec3(traceOrigin);

		//tracePos += dda_step(stepAxis, nextDist, stepSizes, traceDir);

		for (int i = 0; i < VOXEL_GI_MAXSTEP && !hit; i++) {
			vec3 stepAxisNext;
			vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, traceDir);

			voxelPos = ivec3(floor(fma(step, vec3(0.5), tracePos)));

			if (!IsInVoxelBounds(voxelPos)) {
				//tracePos += step;
				break;
			}

			uint blockId = imageLoad(imgVoxelBlock, voxelPos).r;
			//if (blockId <= 0u) continue;

			//bool isFullBlock = iris_isFullBlock(blockId);
			if (blockId > 0u && iris_isFullBlock(blockId)) {
				hit = true;
				break;
			}

			tracePos += step;
			stepAxis = stepAxisNext;

			if (blockId > 0) {
				// TODO: Is this reliable?
				vec3 blockColor = iris_getLightColor(blockId).rgb;
				traceTint *= RgbToLinear(blockColor);

//				uint meta = iris_getMetadata(blockId);
//				uint blocking = bitfieldExtract(meta, 10, 4);
//				traceTint *= 1.0 - blocking/16.0;
			}
		}

		if (hit) {
//			hitPos = currPos;
			vec3 hitNormal = -sign(traceDir) * stepAxis;

			int blockFaceIndex = GetVoxelBlockFaceIndex(hitNormal);
			int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(voxelPos, blockFaceIndex);
			VoxelBlockFace blockFace = VoxelBlockFaceMap[blockFaceMapIndex];

			vec2 hitCoord;
			if (abs(hitNormal.y) > 0.5)      hitCoord = tracePos.xz;
			else if (abs(hitNormal.z) > 0.5) hitCoord = tracePos.xy;
			else                             hitCoord = tracePos.zy;

			hitCoord = 1.0 - fract(hitCoord);

			vec3 tex_tint = GetBlockFaceTint(blockFace.data);
			vec2 hit_lmcoord = GetBlockFaceLightMap(blockFace.data);
			hit_lmcoord = _pow3(hit_lmcoord);

			iris_TextureInfo tex = iris_getTexture(blockFace.tex_id);
			vec2 hit_uv = fma(hitCoord, tex.maxCoord - tex.minCoord, tex.minCoord);

			vec4 hitColor = textureLod(blockAtlas, hit_uv, 4);
			vec3 albedo = RgbToLinear(hitColor.rgb * tex_tint);

			#if MATERIAL_FORMAT != MAT_NONE
				vec4 hit_specularData = textureLod(blockAtlasS, hit_uv, 0);

				//vec3 hit_localTexNormal = mat_normal(reflect_normalData);
				float hit_roughness = mat_roughness(hit_specularData.r);
				float hit_f0_metal = hit_specularData.g;
				float hit_emission = mat_emission(hit_specularData);
			#else
				//vec3 hit_localTexNormal = localGeoNormal;
				float hit_roughness = 0.92;
				float hit_f0_metal = 0.0;
				float hit_emission = 0.0;
			#endif

			float hit_roughL = _pow2(hit_roughness);
			vec3 hit_localPos = GetVoxelLocalPos(tracePos);
			float hit_NoL = dot(-traceDir, hitNormal);

			#ifdef SHADOWS_ENABLED
				int hit_shadowCascade;
				vec3 hit_shadowViewPos = mul3(ap.celestial.view, hit_localPos);
				vec3 hit_shadowPos = GetShadowSamplePos(hit_shadowViewPos, 0.0, hit_shadowCascade);
				hit_shadowPos.z -= GetShadowBias(hit_shadowCascade);

				vec3 hit_shadow = vec3(Scene_SkyBrightnessSmooth);
				if (hit_shadowCascade >= 0)
					hit_shadow = SampleShadowColor(hit_shadowPos, hit_shadowCascade);
			#else
				float hit_shadow = 1.0;
			#endif

			vec3 hit_sunTransmit, hit_moonTransmit;
			GetSkyLightTransmission(hit_localPos, hit_sunTransmit, hit_moonTransmit);

			float NoL_sun = dot(hitNormal, Scene_LocalSunDir);
			float NoL_moon = -NoL_sun;//dot(localTexNormal, -Scene_LocalSunDir);

			vec3 skyLight = SUN_BRIGHTNESS * hit_sunTransmit * max(NoL_sun, 0.0)
				+ MOON_BRIGHTNESS * hit_moonTransmit * max(NoL_moon, 0.0);

			vec3 hit_diffuse = skyLight * hit_shadow;
			//hit_diffuse *= SampleLightDiffuse(hit_NoVm, hit_NoLm, hit_LoHm, hit_roughL);

//			vec2 skyIrradianceCoord = DirectionToUV(hitNormal);
//			vec3 hit_skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
//			hit_diffuse += (SKY_AMBIENT * hit_lmcoord.y) * hit_skyIrradiance;

			//hit_diffuse += 0.0016;

			#if LIGHTING_MODE == LIGHT_MODE_LPV
				ivec3 voxelFrameOffset = GetVoxelFrameOffset();
				vec3 lpv_sample_pos = tracePos + voxelFrameOffset + 0.5*hitNormal;

				if (IsInVoxelBounds(lpv_sample_pos)) {
					vec3 texcoord = lpv_sample_pos / VoxelBufferSize;
					bool altFrame = ap.time.frames % 2 == 1;

					vec3 lpv_light = altFrame
						? textureLod(texFloodFill, texcoord, 0).rgb
						: textureLod(texFloodFill_alt, texcoord, 0).rgb;

					hit_diffuse += lpv_light * BLOCKLIGHT_BRIGHTNESS;
				}
			#else
				hit_diffuse += blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * hit_lmcoord.x);
			#endif

			float hit_metalness = mat_metalness(hit_f0_metal);
			hit_diffuse *= 1.0 - hit_metalness * (1.0 - hit_roughL);

			#if MATERIAL_EMISSION_POWER != 1
				hit_diffuse += pow(hit_emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness;
			#else
				hit_diffuse += hit_emission * Material_EmissionBrightness;
			#endif

			color = albedo * hit_diffuse;// * max(hit_NoL, 0.0);
		}
		else {
			//ivec3 endCell = ivec3(tracePos);
			if (IsInVoxelBounds(voxelPos)) {
				bool altFrame = ap.time.frames % 2 == 1;
				int i_end = GetVoxelIndex(voxelPos);

				uvec2 endVoxel_face;
				if (altFrame) endVoxel_face = SH_LPV[i_end].data[face_dir];
				else endVoxel_face = SH_LPV_alt[i_end].data[face_dir];

				float face_counter;
				decode_shVoxel_dir(endVoxel_face, color, face_counter);

//				lpvShVoxel endVoxel;
//				if (altFrame) endVoxel = SH_LPV[i_end];
//				else endVoxel = SH_LPV_alt[i_end];
//
//				color = sample_sh_gi(endVoxel, traceDir);
			}
			else {
				vec3 skyPos = getSkyPosition(vec3(0.0));
				color = SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, traceDir, Scene_LocalSunDir);
			}
		}

		return color * traceTint;
	}
#endif


void main() {
	uvec3 chunkPos = gl_WorkGroupID * gl_WorkGroupSize;
	if (any(greaterThanEqual(chunkPos, VoxelBufferSize))) return;

	ivec3 voxelFrameOffset = GetVoxelFrameOffset();

	populateShared(voxelFrameOffset);
	barrier();

	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	if (any(greaterThanEqual(cellIndex, VoxelBufferSize))) return;

	bool altFrame = ap.time.frames % 2 == 1;

    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 voxelCenter = GetVoxelCenter(ap.camera.pos, viewDir);
    vec3 localPos = cellIndex - voxelCenter + 0.5;

	ivec3 localCellIndex = ivec3(gl_LocalInvocationID);
	int sharedCoord = getSharedCoord(localCellIndex + 1);
	uint blockId = sharedBlockMap[sharedCoord];

	bool isFullBlock = false;
	vec3 blockTint = vec3(1.0);
	vec3 lightColor = vec3(0.0);
	int lightRange = 0;

	if (blockId > 0u) {
		isFullBlock = iris_isFullBlock(blockId);

		#if LIGHTING_MODE == LIGHT_MODE_LPV
			lightColor = iris_getLightColor(blockId).rgb;
			lightColor = RgbToLinear(lightColor);

			lightRange = iris_getEmission(blockId);

			if (lightRange == 0) {
				// TODO: is this reliable?
				blockTint = lightColor;

//				uint meta = sharedBlockMetaMap[sharedCoord];
//				uint blocking = bitfieldExtract(meta, 10, 4);
//				blockTint *= 1.0 - blocking/16.0;
			}
		#endif
	}

	#if LIGHTING_MODE == LIGHT_MODE_LPV
		vec3 accumLight = vec3(0.0);

		if (!isFullBlock) {
			uint faceMask = 0u;
			if (blockId > 0u)
				faceMask = sharedBlockMetaMap[sharedCoord];

			accumLight = mixNeighbours(localCellIndex + 1, faceMask) * blockTint;
		}

		if (lightRange > 0) {
			vec3 hsv = RgbToHsv(lightColor);
			hsv.z = pow(6.0, (1.0/15.0) * lightRange) - 1.0;
			accumLight += HsvToRgb(hsv);
		}

		vec3 hsv = RgbToHsv(accumLight);
		hsv.z = log6(hsv.z + 1.0) / LpvBlockRange;
		accumLight = HsvToRgb(hsv);

		if (altFrame) imageStore(imgFloodFill_alt, cellIndex, vec4(accumLight, 1.0));
		else imageStore(imgFloodFill, cellIndex, vec4(accumLight, 1.0));
	#endif

	#ifdef VOXEL_GI_ENABLED
		lpvShVoxel voxel_gi = voxel_empty;

		if (!isFullBlock) {
			ivec3 cellIndex_prev = cellIndex + voxelFrameOffset;
			if (IsInVoxelBounds(cellIndex_prev)) {
				int i_prev = GetVoxelIndex(cellIndex_prev);

				if (altFrame) voxel_gi = SH_LPV[i_prev];
				else voxel_gi = SH_LPV_alt[i_prev];
			}

			float seed_pos = hash13(cellIndex);

			for (int dir = 0; dir < 6; dir++) {
				vec3 face_color;
				float face_counter;
				decode_shVoxel_dir(voxel_gi.data[dir], face_color, face_counter);

				vec2 noise_seed = cellIndex.xz * vec2(71.0, 83.0) + cellIndex.y * 67.0;
				noise_seed += (ap.time.frames + dir) * vec2(71.0, 83.0);
				//vec3 noise_dir = sample_blueNoise(hash23(cellIndex));

				vec3 noise_dir = hash33(vec3(seed_pos, dir, ap.time.frames));
				noise_dir = normalize(noise_dir * 2.0 - 1.0);

				float f = dot(shVoxel_dir[dir], noise_dir);
				if (f < 0.0) {
					noise_dir = -noise_dir;
					f = -f;
				}

				//noise_dir = mix(noise_dir, shVoxel_dir[dir], 0.5);
				//noise_dir = normalize(noise_dir);

				//vec3 noise_offset = sample_blueNoise(hash23(cellIndex));
				vec3 noise_offset = vec3(0.5);//hash32(noise_seed);

				vec3 tracePos = cellIndex + noise_offset;
				vec3 traceSample = trace_GI(tracePos, noise_dir, dir);
				face_counter = clamp(face_counter + f, 0.0, VOXEL_GI_MAXFRAMES);

				float mixF = 1.0 / (1.0 + face_counter);
				face_color = mix(face_color, traceSample, mixF);// * max(f, 0.0);

				voxel_gi.data[dir] = encode_shVoxel_dir(face_color, face_counter);
			}
		}

		int i = GetVoxelIndex(cellIndex);

		if (altFrame) SH_LPV_alt[i] = voxel_gi;
		else SH_LPV[i] = voxel_gi;
	#endif
}
