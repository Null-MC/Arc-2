vec3 wsgi_sample_voxel_face(const in uvec2 voxel_face, const in vec3 faceDir, const in vec3 sampleDir, out float face_counter) {
	vec3 face_color;
	decode_shVoxel_dir(voxel_face, face_color, face_counter);
	float theta = dot(faceDir, sampleDir);
	return face_color * max(theta, 0.0);
}

vec3 wsgi_sample_voxel(const in lpvShVoxel voxel, const in vec3 sampleDir) {
	vec3 color = vec3(0.0);
	float face_counter;

	for (int dir = 0; dir < 6; dir++) {
		color += wsgi_sample_voxel_face(voxel.data[dir], shVoxel_dir[dir], sampleDir, face_counter);
	}

	return color;
}

vec3 wsgi_sample_nearest(const in ivec3 bufferPos, const in vec3 sampleDir, const in int cascade) {
	if (!wsgi_isInBounds(bufferPos)) return vec3(0.0);

	int i = wsgi_getBufferIndex(bufferPos, cascade);
	bool altFrame = ap.time.frames % 2 == 1;

	lpvShVoxel sh_voxel;
	if (altFrame) sh_voxel = SH_LPV_alt[i];
	else sh_voxel = SH_LPV[i];

	return wsgi_sample_voxel(sh_voxel, sampleDir);
}

vec3 wsgi_sample_linear(const in vec3 bufferPos, const in vec3 sampleDir, const in int cascade) {
	ivec3 voxelPos_nn = ivec3(bufferPos - 0.5);
	vec3 f = fract(bufferPos - 0.5);
	f = f*f * (3.0 - 2.0*f);

	vec3 sample_x00 = wsgi_sample_nearest(voxelPos_nn,                sampleDir, cascade);
	vec3 sample_x01 = wsgi_sample_nearest(voxelPos_nn + ivec3(0,1,0), sampleDir, cascade);
	vec3 sample_x10 = wsgi_sample_nearest(voxelPos_nn + ivec3(1,0,0), sampleDir, cascade);
	vec3 sample_x11 = wsgi_sample_nearest(voxelPos_nn + ivec3(1,1,0), sampleDir, cascade);

	vec3 sample_y0 = mix(sample_x00, sample_x01, f.y);
	vec3 sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z0 = mix(sample_y0, sample_y1, f.x);

	sample_x00 = wsgi_sample_nearest(voxelPos_nn + ivec3(0,0,1), sampleDir, cascade);
	sample_x01 = wsgi_sample_nearest(voxelPos_nn + ivec3(0,1,1), sampleDir, cascade);
	sample_x10 = wsgi_sample_nearest(voxelPos_nn + ivec3(1,0,1), sampleDir, cascade);
	sample_x11 = wsgi_sample_nearest(voxelPos_nn + ivec3(1,1,1), sampleDir, cascade);

	sample_y0 = mix(sample_x00, sample_x01, f.y);
	sample_y1 = mix(sample_x10, sample_x11, f.y);
	vec3 sample_z1 = mix(sample_y0, sample_y1, f.x);

	return mix(sample_z0, sample_z1, f.z);
}

vec3 wsgi_sample(const in vec3 localPos, const in vec3 sampleDir) {
	int wsgi_cascade = -1;
	vec3 wsgi_bufferPos;

	vec3 face_dir;
	if      (sampleDir.x >  0.5) face_dir = vec3( 1, 0, 0);
	else if (sampleDir.x < -0.5) face_dir = vec3(-1, 0, 0);
	else if (sampleDir.z >  0.5) face_dir = vec3( 0, 0, 1);
	else if (sampleDir.z < -0.5) face_dir = vec3( 0, 0,-1);
	else if (sampleDir.y >  0.5) face_dir = vec3( 0, 1, 0);
	else                         face_dir = vec3( 0,-1, 0);

	for (int i = 0; i < WSGI_CASCADE_COUNT; i++) {
		wsgi_bufferPos = wsgi_getBufferPosition(localPos, i+WSGI_SCALE_BASE);
		wsgi_bufferPos += face_dir;

		if (wsgi_isInBounds(wsgi_bufferPos)) {
			wsgi_cascade = i;
			break;
		}
	}

	vec3 color = vec3(0.0);
	if (wsgi_cascade >= 0)
		color = wsgi_sample_linear(wsgi_bufferPos, sampleDir, wsgi_cascade) * 1000.0;

	return color;
}
