const int EFFECT_TAA_MAX_FRAMES = 8;

const vec2 taa_offsets[8] = vec2[](
	vec2(0.5625, 0.3125),
	vec2(0.4375, 0.6875),
	vec2(0.8125, 0.5625),
	vec2(0.3125, 0.1875),
	vec2(0.1875, 0.8125),
	vec2(0.0625, 0.4375),
	vec2(0.6875, 0.9375),
	vec2(0.9375, 0.0625));


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
