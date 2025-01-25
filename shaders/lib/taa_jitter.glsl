const int EFFECT_TAA_MAX_FRAMES = 4;

const vec2 taa_offsets[4] = vec2[](
	vec2(0.375, 0.125),
	vec2(0.875, 0.375),
	vec2(0.125, 0.625),
	vec2(0.625, 0.875));


vec2 getJitterOffset(const in int frameOffset) {
	return (taa_offsets[frameOffset % EFFECT_TAA_MAX_FRAMES] - 0.5) / ap.game.screenSize;
}

void jitter(inout vec2 ndcPos) {
	vec2 offset = getJitterOffset(ap.frame.counter);
	ndcPos += 2.0 * offset;// * ndcPos.w;
}

void jitter(inout vec4 ndcPos) {
	vec2 offset = getJitterOffset(ap.frame.counter);
	ndcPos.xy += 2.0 * offset * ndcPos.w;
}

void unjitter(inout vec2 ndcPos) {
	vec2 offset = getJitterOffset(ap.frame.counter);
	ndcPos -= 2.0 * offset;// * ndcPos.w;
}

void unjitter(inout vec3 ndcPos) {
	vec2 offset = getJitterOffset(ap.frame.counter);
	ndcPos.xy -= 2.0 * offset;// * ndcPos.w;
}
