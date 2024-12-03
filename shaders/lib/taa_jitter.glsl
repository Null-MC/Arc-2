const int EFFECT_TAA_MAX_FRAMES = 4;

const vec2 taa_offsets[4] = vec2[](
	vec2(0.375, 0.125),
	vec2(0.875, 0.375),
	vec2(0.125, 0.625),
	vec2(0.625, 0.875));


vec2 getJitterOffset(const in int frameOffset) {
	return (taa_offsets[frameOffset % EFFECT_TAA_MAX_FRAMES] - 0.5) / screenSize;
}

void jitter(inout vec4 ndcPos) {
	vec2 offset = getJitterOffset(frameCounter);
	ndcPos.xy += 2.0 * offset * ndcPos.w;
}

void unjitter(inout vec3 ndcPos) {
	vec2 offset = getJitterOffset(frameCounter);
	ndcPos.xy -= 2.0 * offset;// * ndcPos.w;
}
