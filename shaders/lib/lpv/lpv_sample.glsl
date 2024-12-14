vec3 sample_lpv(vec3 voxelPos, vec3 localNormal) {
	if (!IsInVoxelBounds(voxelPos)) return vec3(0.0);

	bool altFrame = frameCounter % 2 == 1;

	int i = GetLpvIndex(ivec3(voxelPos));
	lpvShVoxel sh_voxel = altFrame ? SH_LPV_alt[i] : SH_LPV[i];
	
	// return SH_Evaluate(localNormal, sh_voxel);

	// vec3 sampleCoord = voxelPos / VoxelBufferSize;
	// vec4 lpv_R = textureLod(altFrame ? texLpvR_alt : texLpvR, sampleCoord, 0);
	// vec4 lpv_G = textureLod(altFrame ? texLpvG_alt : texLpvG, sampleCoord, 0);
	// vec4 lpv_B = textureLod(altFrame ? texLpvB_alt : texLpvB, sampleCoord, 0);

	// https://github.com/mafian89/Light-Propagation-Volumes/blob/master/shaders/basicShader.frag
	vec4 intensity = dirToSH(-localNormal);

	vec3 lpv_intensity = vec3(
		dot(intensity, sh_voxel.R),
		dot(intensity, sh_voxel.G),
		dot(intensity, sh_voxel.B));

	vec3 radiance_final = max(lpv_intensity, vec3(0.0)) / PI;

	// float lum = luminance(radiance_final);
	// if (lum > EPSILON) {
	// 	float lum_new = log2(lum + 1.0);
	// 	radiance_final *= lum_new / lum;
	// }

	return radiance_final;
}
