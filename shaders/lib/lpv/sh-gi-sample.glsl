#define SH_GI_SAMPLE_FANCY


vec3 sample_sh_gi(ivec3 voxelPos, vec3 sampleDir) {
	if (!IsInVoxelBounds(voxelPos)) return vec3(0.0);

	int i = GetVoxelIndex(voxelPos);
	bool altFrame = ap.time.frames % 2 == 1;

	lpvShVoxel sh_voxel;
	if (altFrame) sh_voxel = SH_LPV_alt[i];
	else sh_voxel = SH_LPV[i];

	vec3 color = vec3(0.0);

	for (int dir = 0; dir < 6; dir++) {
		vec3 face_color;
		float face_counter;
		decode_shVoxel_dir(sh_voxel.data[dir], face_color, face_counter);
		float f = max(dot(shVoxel_dir[dir], sampleDir), 0.0);
		color += f * face_color;
	}

	return color;
}

vec3 sample_sh_gi_linear(vec3 voxelPos, vec3 sampleDir) {
	ivec3 voxelPos_nn = ivec3(voxelPos - 0.5);
	vec3 f = fract(voxelPos - 0.5);

	vec3 sample_x00 = sample_sh_gi(voxelPos_nn,                sampleDir);
	vec3 sample_x01 = sample_sh_gi(voxelPos_nn + ivec3(0,1,0), sampleDir);
	vec3 sample_x10 = sample_sh_gi(voxelPos_nn + ivec3(1,0,0), sampleDir);
	vec3 sample_x11 = sample_sh_gi(voxelPos_nn + ivec3(1,1,0), sampleDir);

	vec3 sample_y0 = mix(sample_x00, sample_x01, f.y);
	vec3 sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z0 = mix(sample_y0, sample_y1, f.x);

	sample_x00 = sample_sh_gi(voxelPos_nn + ivec3(0,0,1), sampleDir);
	sample_x01 = sample_sh_gi(voxelPos_nn + ivec3(0,1,1), sampleDir);
	sample_x10 = sample_sh_gi(voxelPos_nn + ivec3(1,0,1), sampleDir);
	sample_x11 = sample_sh_gi(voxelPos_nn + ivec3(1,1,1), sampleDir);

	sample_y0 = mix(sample_x00, sample_x01, f.y);
	sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z1 = mix(sample_y0, sample_y1, f.x);

	vec3 sample_final = mix(sample_z0, sample_z1, f.z);

	return sample_final; // * PI;
}
