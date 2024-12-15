#version 430 core

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r8ui) uniform readonly uimage3D imgVoxelBlock;

#ifdef LPV_RSM_ENABLED
	uniform sampler2DArray solidShadowMap;
	uniform sampler2DArray texShadowColor;
	uniform sampler2DArray texShadowNormal;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/sh-lpv.glsl"

#include "/lib/noise/hash.glsl"

#include "/lib/voxel/voxel_common.glsl"

#include "/lib/lpv/lpv_common.glsl"

#include "/lib/shadow/csm.glsl"


const float directFaceSubtendedSolidAngle = 0.4006696846 / PI / 2.0;
const float sideFaceSubtendedSolidAngle = 0.4234413544 / PI / 2.0;

const ivec3 directions[] = {
	ivec3( 0, 0, 1),
	ivec3( 0, 0,-1),
	ivec3( 1, 0, 0),
	ivec3(-1, 0, 0),
	ivec3( 0, 1, 0),
	ivec3( 0,-1, 0)
};

// With a lot of help from: http://blog.blackhc.net/2010/07/light-propagation-volumes/
// This is a fully functioning LPV implementation

// right up
ivec2 side[4] = {
	ivec2( 1.0,  0.0),
	ivec2( 0.0,  1.0),
	ivec2(-1.0,  0.0),
	ivec2( 0.0, -1.0)
};

// orientation = [ right | up | forward ] = [ x | y | z ]
vec3 getEvalSideDirection(uint index, mat3 orientation) {
	return orientation * vec3(side[index] * 0.4472135, 0.894427);
}

vec3 getReprojSideDirection(uint index, mat3 orientation) {
	return orientation * vec3(side[index], 0.0);
}

// orientation = [ right | up | forward ] = [ x | y | z ]
mat3 neighbourOrientations[6] = {
	// Z+
	mat3(
		-1, 0, 0,
		0, 1, 0, 
		0, 0, -1),
	// Z-
	mat3(
		1, 0,  0,
		 0, 1,  0,
		 0, 0, 1),
	// X+
	mat3(
		 0, 0, 1,
		 0, 1, 0,
		-1, 0, 0),
	// X-
	mat3(
		0, 0, -1,
		0, 1,  0,
		1, 0,  0),
	// Y+
	mat3(
		1,  0, 0,
		0,  0, 1,
		0, -1, 0),
	// Y-
	mat3(
		1, 0,  0,
		0, 0, -1,
		0, 1,  0),
};

#ifdef LPV_RSM_ENABLED
	void sample_shadow(vec3 localPos, out vec3 sample_color, out vec3 sample_normal) {
		localPos += hash33(cameraPos + localPos + (frameCounter % 8)) - 0.5;

		vec3 shadowViewPos = mul3(shadowModelView, localPos);

		int shadowCascade;
		vec3 shadowCoord = GetShadowSamplePos(shadowViewPos, shadowCascade);

		float shadowDepth = textureLod(solidShadowMap, vec3(shadowCoord.xy, shadowCascade), 0).r;

		// WARN: FIX
		mat4 shadowProjectionInverse = inverse(shadowProjection[shadowCascade]);

		vec3 sample_ndcPos = vec3(shadowCoord.xy, shadowDepth) * 2.0 - 1.0;
		vec3 sample_shadowViewPos = mul3(shadowProjectionInverse, sample_ndcPos);

		if (distance(shadowViewPos, sample_shadowViewPos) > 1.0) {
			sample_color = vec3(0.0);
			sample_normal = vec3(0.0);
			return;
		}

		sample_color = textureLod(texShadowColor, vec3(shadowCoord.xy, shadowCascade), 0).rgb;

		// TODO: sample normal
		sample_normal = textureLod(texShadowNormal, vec3(shadowCoord.xy, shadowCascade), 0).rgb;
		sample_normal = normalize(sample_normal * 2.0 - 1.0);
		// sample_normal = vec3(0.0, 1.0, 0.0);

		sample_color *= max(dot(sample_normal, Scene_LocalLightDir), 0.0);
	}
#endif

void main() {
	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	bool altFrame = frameCounter % 2 == 1;

	lpvShVoxel sh_voxel = voxel_empty;

	#ifdef LPV_RSM_ENABLED
		lpvShVoxel sh_rsm_voxel = voxel_empty;
	#endif

	ivec3 cellIndexPrev = cellIndex + ivec3(floor(cameraPos) - floor(lastCameraPos));

	uint blockId = imageLoad(imgVoxelBlock, cellIndex).r;

	if (blockId == 0u) {
		for (uint neighbour = 0; neighbour < 6; ++neighbour) {
			mat3 orientation = neighbourOrientations[neighbour];
			// TODO: transpose all orientation matrices and use row indexing instead? ie int3( orientation[2] )
			// vec3 mainDirection = orientation * vec3(0.0, 0.0, 1.0);

			ivec3 curDir = directions[neighbour];
			ivec3 neighbourIndex = cellIndexPrev + curDir;
			if (!IsInVoxelBounds(neighbourIndex)) continue;

			uint neighborBlockId = imageLoad(imgVoxelBlock, cellIndex + curDir).r;

			if (neighborBlockId == 2u) {
				vec4 coeffs = dirToSH(vec3(-curDir)) / PI;
				vec3 flux = vec3(2000.0);

				sh_voxel.R += coeffs * flux.r;
				sh_voxel.G += coeffs * flux.g;
				sh_voxel.B += coeffs * flux.b;
			}
			else if (neighborBlockId == 0u) {
				int neighbor_i = GetLpvIndex(neighbourIndex);
				lpvShVoxel neighbor_voxel = altFrame ? SH_LPV[neighbor_i] : SH_LPV_alt[neighbor_i];


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

				sh_voxel.R += max(dot(neighbor_voxel.R, curDirSH), 0.0) * f;
				sh_voxel.G += max(dot(neighbor_voxel.G, curDirSH), 0.0) * f;
				sh_voxel.B += max(dot(neighbor_voxel.B, curDirSH), 0.0) * f;

				// sh_voxel.R += max(neighbor_voxel.R, 0.0) * f;
				// sh_voxel.G += max(neighbor_voxel.G, 0.0) * f;
				// sh_voxel.B += max(neighbor_voxel.B, 0.0) * f;
			}
		}

		#ifdef LPV_RSM_ENABLED
			vec3 sample_color, sample_normal;
			vec3 localPos = cellIndex - VoxelBufferCenter - fract(cameraPos) + 0.5;
			sample_shadow(localPos, sample_color, sample_normal);

			vec4 coeffs = dirToSH(sample_normal) / PI;
			vec3 flux = 12000.0 * RgbToLinear(sample_color);

			sh_rsm_voxel.R += coeffs * flux.r;
			sh_rsm_voxel.G += coeffs * flux.g;
			sh_rsm_voxel.B += coeffs * flux.b;

			// TODO: mix RSM previous
			int rsm_i = GetLpvIndex(cellIndexPrev);
			lpvShVoxel rsm_voxel_prev = altFrame ? SH_LPV_RSM[rsm_i] : SH_LPV_RSM_alt[rsm_i];
			sh_rsm_voxel.R = mix(rsm_voxel_prev.R, sh_rsm_voxel.R, 0.02);
			sh_rsm_voxel.G = mix(rsm_voxel_prev.G, sh_rsm_voxel.G, 0.02);
			sh_rsm_voxel.B = mix(rsm_voxel_prev.B, sh_rsm_voxel.B, 0.02);

			sh_voxel.R += sh_rsm_voxel.R;
			sh_voxel.G += sh_rsm_voxel.G;
			sh_voxel.B += sh_rsm_voxel.B;
		#endif
	}

	// ivec3 trackPos = ivec3(floor(GetVoxelPosition(Scene_TrackPos - cameraPos)));

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

	int i = GetLpvIndex(cellIndex);

	if (altFrame) SH_LPV_alt[i] = sh_voxel;
	else SH_LPV[i] = sh_voxel;

	#ifdef LPV_RSM_ENABLED
		if (altFrame) SH_LPV_RSM_alt[i] = sh_rsm_voxel;
		else SH_LPV_RSM[i] = sh_rsm_voxel;
	#endif
}
