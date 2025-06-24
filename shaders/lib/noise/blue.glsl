// seed = gl_FragCoord.xy
vec3 sample_blueNoise(const in vec2 seed) {
	//vec2 texSize = textureSize(texBlueNoise, 0);
	const vec2 texSize = vec2(512.0);
	vec2 coord = (seed + vec2(71.0, 83.0) * ap.time.frames) / texSize;
	return textureLod(texBlueNoise, coord, 0).rgb;
}

vec3 sample_blueNoiseNorm(const in vec2 seed) {
	//vec2 texSize = textureSize(texBlueNoise, 0);
	const vec2 texSize = vec2(512.0);
	vec2 coord = (seed + vec2(71.0, 83.0) * ap.time.frames) / texSize;
	vec3 noise = textureLod(texBlueNoise, coord, 0).rgb;
	return normalize(noise * 2.0 - 1.0);
}
