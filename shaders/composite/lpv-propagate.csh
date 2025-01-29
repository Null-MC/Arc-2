#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#ifdef LPV_RSM_ENABLED
	uniform sampler2DArray solidShadowMap;
	uniform sampler2DArray texShadowColor;
	uniform sampler2DArray texShadowNormal;

	uniform sampler2D texSkyTransmit;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/voxel-block.glsl"
#include "/lib/buffers/sh-lpv.glsl"

#include "/lib/noise/hash.glsl"

#include "/lib/voxel/voxel_common.glsl"

#include "/lib/lpv/lpv_common.glsl"

#ifdef LPV_RSM_ENABLED
	#include "/lib/shadow/csm.glsl"

	#include "/lib/sky/common.glsl"
	#include "/lib/sky/sun.glsl"
#endif


const float directFaceSubtendedSolidAngle = 0.4006696846 / PI / 2.0;
const float sideFaceSubtendedSolidAngle = 0.4234413544 / PI / 2.0;

const ivec3 directions[] = {
	ivec3( 0,-1, 0),
	ivec3( 0, 1, 0),
	ivec3( 0, 0,-1),
	ivec3( 0, 0, 1),
	ivec3(-1, 0, 0),
	ivec3( 1, 0, 0),
};

// With a lot of help from: http://blog.blackhc.net/2010/07/light-propagation-volumes/
// This is a fully functioning LPV implementation

// right up
// ivec2 side[4] = {
// 	ivec2( 1.0,  0.0),
// 	ivec2( 0.0,  1.0),
// 	ivec2(-1.0,  0.0),
// 	ivec2( 0.0, -1.0)
// };

// orientation = [ right | up | forward ] = [ x | y | z ]
// vec3 getEvalSideDirection(uint index, mat3 orientation) {
// 	return orientation * vec3(side[index] * 0.4472135, 0.894427);
// }

// vec3 getReprojSideDirection(uint index, mat3 orientation) {
// 	return orientation * vec3(side[index], 0.0);
// }

// orientation = [ right | up | forward ] = [ x | y | z ]
// mat3 neighbourOrientations[6] = {
// 	// Z+
// 	mat3(
// 		-1, 0, 0,
// 		0, 1, 0, 
// 		0, 0, -1),
// 	// Z-
// 	mat3(
// 		1, 0,  0,
// 		 0, 1,  0,
// 		 0, 0, 1),
// 	// X+
// 	mat3(
// 		 0, 0, 1,
// 		 0, 1, 0,
// 		-1, 0, 0),
// 	// X-
// 	mat3(
// 		0, 0, -1,
// 		0, 1,  0,
// 		1, 0,  0),
// 	// Y+
// 	mat3(
// 		1,  0, 0,
// 		0,  0, 1,
// 		0, -1, 0),
// 	// Y-
// 	mat3(
// 		1, 0,  0,
// 		0, 0, -1,
// 		0, 1,  0),
// };

#ifdef LPV_RSM_ENABLED
	void sample_shadow(vec3 localPos, out vec3 sample_color, out vec3 sample_normal) {
		localPos += hash33(ap.camera.pos + localPos + (ap.frame.counter % 16));// - 0.5;

		//localPos -= 0.5;

		vec3 shadowViewPos = mul3(ap.celestial.view, localPos);

		int shadowCascade;
		vec3 shadowCoord = GetShadowSamplePos(shadowViewPos, 0.0, shadowCascade);

		float shadowDepth = textureLod(solidShadowMap, vec3(shadowCoord.xy, shadowCascade), 0).r;

		// WARN: FIX
		mat4 shadowProjectionInverse = inverse(ap.celestial.projection[shadowCascade]);

		vec3 sample_ndcPos = vec3(shadowCoord.xy, shadowDepth) * 2.0 - 1.0;
		vec3 sample_shadowViewPos = mul3(shadowProjectionInverse, sample_ndcPos);

		//shadowViewPos.z -= 2.0;
		if (distance(shadowViewPos, sample_shadowViewPos) > 1.0) {
			sample_color = vec3(0.0);
			sample_normal = vec3(0.0);
			return;
		}

		sample_normal = textureLod(texShadowNormal, vec3(shadowCoord.xy, shadowCascade), 0).rgb;
		sample_normal = normalize(sample_normal * 2.0 - 1.0);

		float sampleLit = max(dot(sample_normal, Scene_LocalLightDir), 0.0);

		// TODO: cloud shadow
		sampleLit *= (1.0 - ap.world.rainStrength);

		sample_color = textureLod(texShadowColor, vec3(shadowCoord.xy, shadowCascade), 0).rgb;
		sample_color = RgbToLinear(sample_color) * sampleLit;
	}
#endif

ivec3 GetVoxelFrameOffset() {
    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 posNow = GetVoxelCenter(ap.camera.pos, viewDir);

    vec3 viewDirPrev = vec3(ap.temporal.view[0].z, ap.temporal.view[1].z, ap.temporal.view[2].z);
    vec3 posPrev = GetVoxelCenter(ap.temporal.pos, viewDirPrev);

    vec3 posLast = posNow + (ap.temporal.pos - ap.camera.pos) - (posPrev - posNow);

    return ivec3(posNow) - ivec3(posLast);
}

void main() {
	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	bool altFrame = ap.frame.counter % 2 == 1;

	//lpvShVoxel sh_voxel = voxel_empty;
	vec4 voxel_R = vec4(0.0);
	vec4 voxel_G = vec4(0.0);
	vec4 voxel_B = vec4(0.0);

	#ifdef LPV_RSM_ENABLED
//		lpvShVoxel sh_rsm_voxel = voxel_empty;
		vec4 voxel_rsm_R = vec4(0.0);
		vec4 voxel_rsm_G = vec4(0.0);
		vec4 voxel_rsm_B = vec4(0.0);
	#endif

	ivec3 voxelFrameOffset = GetVoxelFrameOffset();
	ivec3 cellIndexPrev = cellIndex + voxelFrameOffset;

    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 voxelCenter = GetVoxelCenter(ap.camera.pos, viewDir);
    vec3 localPos = cellIndex - voxelCenter + 0.5;

	uint blockId = imageLoad(imgVoxelBlock, cellIndex).r;

	bool isFullBlock = false;
	vec3 tintColor = vec3(1.0);
	uint faceMask = 0u;

	if (blockId > 0u) {
		isFullBlock = iris_isFullBlock(blockId);
		uint blockData = iris_getMetadata(blockId);
		faceMask = bitfieldExtract(blockData, 0, 6);

		tintColor = iris_getLightColor(blockId).rgb;
		tintColor = RgbToLinear(tintColor);

		#ifndef LPV_PER_FACE_LIGHTING
			int lightRange = iris_getEmission(blockId);

			#if LIGHTING_MODE == LIGHT_MODE_LPV
				if (lightRange > 0) {
					vec3 lightColor = tintColor;//iris_getLightColor(neighborBlockId).rgb;
					// lightColor = RgbToLinear(lightColor);

					// vec4 coeffs = vec4(1.0 / PI);//dirToSH(vec3(-curDir)) / PI;
					vec4 coeffs = vec4(0.0);
					coeffs += dirToSH(vec3( 0.0,  1.0,  0.0));
					coeffs += dirToSH(vec3( 0.0, -1.0,  0.0));
					coeffs += dirToSH(vec3( 1.0,  0.0,  0.0));
					coeffs += dirToSH(vec3(-1.0,  0.0,  0.0));
					coeffs += dirToSH(vec3( 0.0,  0.0,  1.0));
					coeffs += dirToSH(vec3( 0.0,  0.0, -1.0));
					coeffs /= PI;
					vec3 flux = exp2(lightRange) * lightColor;

					voxel_R = fma(vec4(flux.r), coeffs, voxel_R);
					voxel_G = fma(vec4(flux.g), coeffs, voxel_G);
					voxel_B = fma(vec4(flux.b), coeffs, voxel_B);
				}
			#endif
		#endif
	}

	if (!isFullBlock) {
		for (uint neighbour = 0; neighbour < 6; ++neighbour) {
			// mat3 orientation = neighbourOrientations[neighbour];

			bool isFaceSolid = bitfieldExtract(faceMask, int(neighbour), 1) == 1u;
			if (isFaceSolid) continue;

			ivec3 curDir = directions[neighbour];
			ivec3 neighbourIndex = cellIndexPrev + curDir;
			if (!IsInVoxelBounds(neighbourIndex)) continue;

			uint neighborBlockId = imageLoad(imgVoxelBlock, cellIndex + curDir).r;
			bool isNeighborFullBlock = false;
			uint neighborfaceMask = 0u;

			if (neighborBlockId != 0u) {
				isNeighborFullBlock = iris_isFullBlock(neighborBlockId);
				int lightRange = iris_getEmission(neighborBlockId);

				#ifdef LPV_PER_FACE_LIGHTING
					uint neighborBlockData = iris_getMetadata(neighborBlockId);
					neighborfaceMask = bitfieldExtract(neighborBlockData, 0, 6);

					// vec3 lightColor = blackbody(BLOCKLIGHT_TEMP);
					// vec3 lightColor = hash33(floor(localPos + ap.camera.pos + curDir));
					// lightColor = normalize(lightColor);
					// lightColor = RgbToLinear(lightColor);

					#if LIGHTING_MODE == LIGHT_MODE_LPV
						if (lightRange > 0) {
							vec3 lightColor = iris_getLightColor(neighborBlockId).rgb;
							lightColor = RgbToLinear(lightColor);

							vec4 coeffs = dirToSH(vec3(-curDir)) / PI;
							vec3 flux = exp2(lightRange) * lightColor * tintColor;

							voxel_R = fma(vec4(flux.r), coeffs, voxel_R);
							voxel_G = fma(vec4(flux.g), coeffs, voxel_G);
							voxel_B = fma(vec4(flux.b), coeffs, voxel_B);
						}
					#endif
				#endif
			}

			uint neighbourInverse = neighbour;
			neighbourInverse += (neighbourInverse % 2 == 0) ? 1 : -1;

			bool isNeighborFaceSolid = bitfieldExtract(neighborfaceMask, int(neighbourInverse), 1) == 1u;
			if (isNeighborFaceSolid) continue;

			// if (!isNeighborFullBlock) {
				int neighbor_i = GetLpvIndex(neighbourIndex);
				lpvShVoxel neighbor_voxel = altFrame ? SH_LPV[neighbor_i] : SH_LPV_alt[neighbor_i];

				vec4 neighbor_R, neighbor_G, neighbor_B;
				decode_shVoxel(neighbor_voxel, neighbor_R, neighbor_G, neighbor_B);


				// for (uint sideFace = 0; sideFace < 4; ++sideFace) {
				// 	vec3 evalDirection = getEvalSideDirection(sideFace, orientation);
				// 	vec3 reprojDirection = getReprojSideDirection(sideFace, orientation);

				// 	vec4 reprojDirectionCosineLobeSH = dirToCosineLobe(reprojDirection);
				// 	vec4 evalDirectionSH = dirToSH(evalDirection);

				// 	sh_voxel.R += sideFaceSubtendedSolidAngle * max(dot(neighbor_voxel.R, evalDirectionSH), 0.0) * reprojDirectionCosineLobeSH;
				// 	sh_voxel.G += sideFaceSubtendedSolidAngle * max(dot(neighbor_voxel.G, evalDirectionSH), 0.0) * reprojDirectionCosineLobeSH;
				// 	sh_voxel.B += sideFaceSubtendedSolidAngle * max(dot(neighbor_voxel.B, evalDirectionSH), 0.0) * reprojDirectionCosineLobeSH;
				// }

				// vec4 curCosLobe = dirToCosineLobe(curDir);
				// vec4 curDirSH = dirToSH(curDir);

				// sh_voxel.R += directFaceSubtendedSolidAngle * max(dot(neighbor_voxel.R, curDirSH), 0.0) * curCosLobe;
				// sh_voxel.G += directFaceSubtendedSolidAngle * max(dot(neighbor_voxel.G, curDirSH), 0.0) * curCosLobe;
				// sh_voxel.B += directFaceSubtendedSolidAngle * max(dot(neighbor_voxel.B, curDirSH), 0.0) * curCosLobe;



				vec4 curCosLobe = dirToCosineLobe(-curDir);
				vec4 curDirSH = dirToSH(-curDir);

				vec4 f = (1.0/2.0) * curCosLobe;

				voxel_R += max(dot(neighbor_R, curDirSH), 0.0) * f * tintColor.r;
				voxel_G += max(dot(neighbor_G, curDirSH), 0.0) * f * tintColor.g;
				voxel_B += max(dot(neighbor_B, curDirSH), 0.0) * f * tintColor.b;
			// }
		}

		#ifdef LPV_RSM_ENABLED
			vec3 sample_color, sample_normal;
			sample_shadow(localPos, sample_color, sample_normal);

	        vec3 skyPos = getSkyPosition(localPos);
	        vec3 sunTransmit = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalSunDir);
	        vec3 moonTransmit = getValFromTLUT(texSkyTransmit, skyPos, -Scene_LocalSunDir);
	        vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;

			vec4 coeffs = dirToSH(sample_normal) / PI;
			vec3 flux = exp2(7.0) * max(Scene_LocalSunDir.y, 0.0) * skyLight * sample_color;

			voxel_rsm_R += coeffs * flux.r;
			voxel_rsm_G += coeffs * flux.g;
			voxel_rsm_B += coeffs * flux.b;

			int rsm_i = GetLpvIndex(cellIndexPrev);
			lpvShVoxel rsm_voxel_prev = altFrame ? SH_LPV_RSM[rsm_i] : SH_LPV_RSM_alt[rsm_i];

			vec4 rsm_prev_R, rsm_prev_G, rsm_prev_B;
			decode_shVoxel(rsm_voxel_prev, rsm_prev_R, rsm_prev_G, rsm_prev_B);

			voxel_rsm_R = mix(rsm_prev_R, voxel_rsm_R, 0.02);
			voxel_rsm_G = mix(rsm_prev_G, voxel_rsm_G, 0.02);
			voxel_rsm_B = mix(rsm_prev_B, voxel_rsm_B, 0.02);

			voxel_R += voxel_rsm_R;
			voxel_G += voxel_rsm_G;
			voxel_B += voxel_rsm_B;
		#endif
	}

	// ivec3 trackPos = ivec3(floor(GetVoxelPosition(Scene_TrackPos - ap.camera.pos)));

	// if (all(equal(cellIndex, trackPos)) && IsInVoxelBounds(trackPos)) {
	// 	const float surfelWeight = 0.015;

	// 	vec4 coeffs = vec4(0.0);
	// 	// coeffs += (dirToCosineLobe(vec3( 1.0, 0.0,  0.0)) / PI);// * surfelWeight;
	// 	// coeffs += (dirToCosineLobe(vec3(-1.0, 0.0,  0.0)) / PI);// * surfelWeight;
	// 	// coeffs += (dirToCosineLobe(vec3( 0.0, 0.0,  1.0)) / PI);// * surfelWeight;
	// 	// coeffs += (dirToCosineLobe(vec3( 0.0, 0.0, -1.0)) / PI);// * surfelWeight;
	// 	coeffs += (dirToCosineLobe(vec3(0.0,  1.0, 0.0)) / PI);// * surfelWeight;
	// 	coeffs += (dirToCosineLobe(vec3(0.0, -1.0, 0.0)) / PI);// * surfelWeight;
	// 	vec3 flux = vec3(100.0, 0.0, 0.0);

	// 	cR += coeffs * flux.r;
	// 	cG += coeffs * flux.g;
	// 	cB += coeffs * flux.b;
	// }

	lpvShVoxel sh_voxel;
	encode_shVoxel(sh_voxel, voxel_R, voxel_G, voxel_B);

	int i = GetLpvIndex(cellIndex);

	if (altFrame) SH_LPV_alt[i] = sh_voxel;
	else SH_LPV[i] = sh_voxel;

	#ifdef LPV_RSM_ENABLED
		lpvShVoxel sh_rsm_voxel;
		encode_shVoxel(sh_rsm_voxel, voxel_rsm_R, voxel_rsm_G, voxel_rsm_B);

		if (altFrame) SH_LPV_RSM_alt[i] = sh_rsm_voxel;
		else SH_LPV_RSM[i] = sh_rsm_voxel;
	#endif
}
