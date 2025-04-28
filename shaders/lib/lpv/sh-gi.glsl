//const float SH_cosLobe_C0 = 0.886226925; // sqrt(pi)/2
//const float SH_cosLobe_C1 = 1.02332671; // sqrt(pi/3)
//
//const float SH_C0 = 0.282094792; // 1 / 2sqrt(pi)
//const float SH_C1 = 0.488602512; // sqrt(3/pi) / 2
//
//
//int GetLpvIndex(ivec3 voxelPos) {
//	const ivec3 flatten = ivec3(1, VOXEL_SIZE, VOXEL_SIZE*VOXEL_SIZE);
//	return sumOf(flatten * voxelPos);
//}
//
//vec4 dirToCosineLobe(vec3 dir) {
//	const vec4 SH = vec4(SH_cosLobe_C0, -SH_cosLobe_C1, SH_cosLobe_C1, -SH_cosLobe_C1);
//	return SH * vec4(1.0, dir.yzx);
//}
//
//vec4 dirToSH(vec3 dir) {
//	const vec4 SH = vec4(SH_C0, -SH_C1, SH_C1, -SH_C1);
//	return SH * vec4(1.0, dir.yzx);
//}
