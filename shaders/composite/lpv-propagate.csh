#version 430 core

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(r8ui) uniform readonly uimage3D imgVoxelBlock;

// layout(rgba16f) uniform image3D imgLpvR;
// layout(rgba16f) uniform image3D imgLpvG;
// layout(rgba16f) uniform image3D imgLpvB;

// layout(rgba16f) uniform image3D imgLpvR_alt;
// layout(rgba16f) uniform image3D imgLpvG_alt;
// layout(rgba16f) uniform image3D imgLpvB_alt;


#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"
#include "/lib/buffers/sh-lpv.glsl"
#include "/lib/voxel/voxel_common.glsl"
#include "/lib/lpv/lpv_common.glsl"


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

const vec3 direction_colors[] = {
	vec3(1.0, 0.0, 0.0),
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0),
	vec3(0.0, 0.0, 1.0)
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

void main() {
	ivec3 cellIndex = ivec3(gl_GlobalInvocationID);
	bool altFrame = frameCounter % 2 == 1;

	// vec4 cR = vec4(0.0);
	// vec4 cG = vec4(0.0);
	// vec4 cB = vec4(0.0);
	// vec4 cR = imageLoad(altFrame ? imgLpvR : imgLpvR_alt, cellIndex); // vec4(0.0);
	// vec4 cG = imageLoad(altFrame ? imgLpvG : imgLpvG_alt, cellIndex); // vec4(0.0);
	// vec4 cB = imageLoad(altFrame ? imgLpvB : imgLpvB_alt, cellIndex); // vec4(0.0);
	lpvShVoxel sh_voxel = voxel_empty;

	// TODO
	ivec3 cellIndexPrev = cellIndex + ivec3(floor(cameraPos) - floor(lastCameraPos));

	uint blockId = imageLoad(imgVoxelBlock, cellIndex).r;

	if (blockId == 2u) {
		// vec3 flux = 200.0 * vec3(0.9, 0.7, 0.5);

		// vec4 coeffs = vec4(0.0);
		// coeffs += (dirToCosineLobe(vec3( 1.0, 0.0,  0.0)) / PI);// * surfelWeight;
		// coeffs += (dirToCosineLobe(vec3(-1.0, 0.0,  0.0)) / PI);// * surfelWeight;
		// coeffs += (dirToCosineLobe(vec3( 0.0, 0.0,  1.0)) / PI);// * surfelWeight;
		// coeffs += (dirToCosineLobe(vec3( 0.0, 0.0, -1.0)) / PI);// * surfelWeight;

		// cR += coeffs * flux.r;
		// cG += coeffs * flux.g;
		// cB += coeffs * flux.b;

		// vec4 coeffs;
		// vec3 flux;

		// coeffs = (dirToCosineLobe(vec3(1.0, 0.0, 0.0)) / PI);// * surfelWeight;
		// flux = vec3(200.0, 0.0, 0.0);

		// cR += coeffs * flux.r;
		// cG += coeffs * flux.g;
		// cB += coeffs * flux.b;

		// coeffs = (dirToCosineLobe(vec3(-1.0, 0.0, 0.0)) / PI);// * surfelWeight;
		// flux = vec3(0.0, 200.0, 0.0);

		// cR += coeffs * flux.r;
		// cG += coeffs * flux.g;
		// cB += coeffs * flux.b;

		// coeffs = (dirToCosineLobe(vec3(0.0, 0.0, 1.0)) / PI);// * surfelWeight;
		// flux = vec3(0.0, 0.0, 200.0);

		// cR += coeffs * flux.r;
		// cG += coeffs * flux.g;
		// cB += coeffs * flux.b;
	}

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
				vec3 flux = vec3(2000.0);// * direction_colors[neighbour];

				sh_voxel.R += coeffs * flux.r;
				sh_voxel.G += coeffs * flux.g;
				sh_voxel.B += coeffs * flux.b;

				// vec3 color = vec3(16.0);// * direction_colors[neighbour];
				// SH_AddLightDirectional(sh_voxel, color, -curDir);
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
				vec4 curDirSH = dirToSH(ivec3(-curDir));

				vec4 f = (1.0/2.0) * curCosLobe;

				sh_voxel.R += max(dot(neighbor_voxel.R, curDirSH), 0.0) * f;
				sh_voxel.G += max(dot(neighbor_voxel.G, curDirSH), 0.0) * f;
				sh_voxel.B += max(dot(neighbor_voxel.B, curDirSH), 0.0) * f;

				// sh_voxel.R += max(neighbor_voxel.R, 0.0) * f;
				// sh_voxel.G += max(neighbor_voxel.G, 0.0) * f;
				// sh_voxel.B += max(neighbor_voxel.B, 0.0) * f;
			}
		}
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

	// imageStore(altFrame ? imgLpvR_alt : imgLpvR, cellIndex, cR); // lpvR[dispatchThreadID.xyz] += cR;
	// imageStore(altFrame ? imgLpvG_alt : imgLpvG, cellIndex, cG); // lpvG[dispatchThreadID.xyz] += cG;
	// imageStore(altFrame ? imgLpvB_alt : imgLpvB, cellIndex, cB); // lpvB[dispatchThreadID.xyz] += cB;
	int i = GetLpvIndex(cellIndex);
	if (altFrame) SH_LPV_alt[i] = sh_voxel;
	else SH_LPV[i] = sh_voxel;
}
