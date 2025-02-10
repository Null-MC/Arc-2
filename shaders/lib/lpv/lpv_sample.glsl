vec3 sample_lpv(ivec3 voxelPos, vec4 intensity) {
	if (!IsInVoxelBounds(voxelPos)) return vec3(0.0);

	int i = GetLpvIndex(voxelPos);
	bool altFrame = ap.time.frames % 2 == 1;

	lpvShVoxel sh_voxel;
	if (altFrame) sh_voxel = SH_LPV_alt[i];
	else sh_voxel = SH_LPV[i];

	vec4 sh_voxel_R, sh_voxel_G, sh_voxel_B;
	decode_shVoxel(sh_voxel, sh_voxel_R, sh_voxel_G, sh_voxel_B);
	
	vec3 lpv_intensity = vec3(
		dot(intensity, sh_voxel_R),
		dot(intensity, sh_voxel_G),
		dot(intensity, sh_voxel_B));

	lpv_intensity = max(lpv_intensity, vec3(0.0));

	// lpv_intensity = max(log2(lpv_intensity + 1.0), 0.0);
	float lum = luminance(lpv_intensity);
	if (lum > EPSILON) {
		float lum_new = max(log(lum + 1.0), 0.0);
		lpv_intensity *= lum_new / lum;
	}

	return lpv_intensity;
}

vec3 sample_lpv_nn(ivec3 voxelPos, vec3 localNormal) {
	vec4 intensity = dirToSH(-localNormal);

	return sample_lpv(voxelPos, intensity);
}

vec3 sample_lpv_linear(vec3 voxelPos, vec3 localNormal) {
	ivec3 voxelPos_nn = ivec3(voxelPos - 0.5);
	vec4 intensity = dirToSH(-localNormal);
	vec3 f = fract(voxelPos - 0.5);

	vec3 sample_x00 = sample_lpv(voxelPos_nn,                intensity);
	vec3 sample_x01 = sample_lpv(voxelPos_nn + ivec3(0,1,0), intensity);
	vec3 sample_x10 = sample_lpv(voxelPos_nn + ivec3(1,0,0), intensity);
	vec3 sample_x11 = sample_lpv(voxelPos_nn + ivec3(1,1,0), intensity);

	vec3 sample_y0 = mix(sample_x00, sample_x01, f.y);
	vec3 sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z0 = mix(sample_y0, sample_y1, f.x);

	sample_x00 = sample_lpv(voxelPos_nn + ivec3(0,0,1), intensity);
	sample_x01 = sample_lpv(voxelPos_nn + ivec3(0,1,1), intensity);
	sample_x10 = sample_lpv(voxelPos_nn + ivec3(1,0,1), intensity);
	sample_x11 = sample_lpv(voxelPos_nn + ivec3(1,1,1), intensity);

	sample_y0 = mix(sample_x00, sample_x01, f.y);
	sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z1 = mix(sample_y0, sample_y1, f.x);

	vec3 sample_final = mix(sample_z0, sample_z1, f.z);

	return sample_final;



	// if (!IsInVoxelBounds(voxelPos)) return vec3(0.0);

	// bool altFrame = ap.time.frames % 2 == 1;

	// int i = GetLpvIndex(ivec3(voxelPos));
	// lpvShVoxel sh_voxel = altFrame ? SH_LPV_alt[i] : SH_LPV[i];
	
	// // https://github.com/mafian89/Light-Propagation-Volumes/blob/master/shaders/basicShader.frag
	// vec4 intensity = dirToSH(-localNormal);

	// vec3 lpv_intensity = vec3(
	// 	dot(intensity, sh_voxel.R),
	// 	dot(intensity, sh_voxel.G),
	// 	dot(intensity, sh_voxel.B));

	// vec3 radiance_final = max(lpv_intensity, vec3(0.0)) / PI;

	// return radiance_final;
}
