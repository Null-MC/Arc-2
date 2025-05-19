#define SH_GI_SAMPLE_FANCY


vec3 sample_gi_voxel(const in lpvShVoxel voxel, const in vec3 sampleDir) {
	vec3 color = vec3(0.0);

	for (int dir = 0; dir < 6; dir++) {
		vec3 face_color;
		float face_counter;
		decode_shVoxel_dir(voxel.data[dir], face_color, face_counter);
		float f = max(dot(shVoxel_dir[dir], sampleDir), 0.0);
		color += f * face_color;
	}

	return color;
}

vec3 sample_gi_nearest(const in ivec3 voxelPos, const in vec3 sampleDir) {
	if (!IsInVoxelBounds(voxelPos)) return vec3(0.0);

	int i = GetVoxelIndex(voxelPos);
	bool altFrame = ap.time.frames % 2 == 1;

	lpvShVoxel sh_voxel;
	if (altFrame) sh_voxel = SH_LPV_alt[i];
	else sh_voxel = SH_LPV[i];

	return sample_gi_voxel(sh_voxel, sampleDir);
}

vec3 sample_gi_linear(const in vec3 voxelPos, const in vec3 sampleDir) {
	ivec3 voxelPos_nn = ivec3(voxelPos - 0.5);
	vec3 f = fract(voxelPos - 0.5);

	vec3 sample_x00 = sample_gi_nearest(voxelPos_nn,                sampleDir);
	vec3 sample_x01 = sample_gi_nearest(voxelPos_nn + ivec3(0,1,0), sampleDir);
	vec3 sample_x10 = sample_gi_nearest(voxelPos_nn + ivec3(1,0,0), sampleDir);
	vec3 sample_x11 = sample_gi_nearest(voxelPos_nn + ivec3(1,1,0), sampleDir);

	vec3 sample_y0 = mix(sample_x00, sample_x01, f.y);
	vec3 sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z0 = mix(sample_y0, sample_y1, f.x);

	sample_x00 = sample_gi_nearest(voxelPos_nn + ivec3(0,0,1), sampleDir);
	sample_x01 = sample_gi_nearest(voxelPos_nn + ivec3(0,1,1), sampleDir);
	sample_x10 = sample_gi_nearest(voxelPos_nn + ivec3(1,0,1), sampleDir);
	sample_x11 = sample_gi_nearest(voxelPos_nn + ivec3(1,1,1), sampleDir);

	sample_y0 = mix(sample_x00, sample_x01, f.y);
	sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z1 = mix(sample_y0, sample_y1, f.x);

	return mix(sample_z0, sample_z1, f.z);
}

vec3 sample_gi(const in vec3 voxelPos, const in vec3 sampleDir) {
	return sample_gi_linear(voxelPos, sampleDir) * 1000.0;
}
