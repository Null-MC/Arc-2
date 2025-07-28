const vec2 taa_offsets[4] = vec2[](
	vec2(0.375, 0.125),
	vec2(0.875, 0.375),
	vec2(0.125, 0.625),
	vec2(0.625, 0.875));


vec2 getJitterOffset(const in int frameOffset, const in vec2 bufferSize) {
	return (taa_offsets[frameOffset % 4]) / bufferSize;
}

void jitter(inout vec2 uv, const in vec2 bufferSize) {
	uv += getJitterOffset(ap.time.frames, bufferSize);
}

void jitter(inout vec2 ndcPos) {
	jitter(ndcPos, ap.game.screenSize*0.5);
}

void jitter(inout vec4 ndcPos) {
	vec2 offset = getJitterOffset(ap.time.frames, ap.game.screenSize);
	ndcPos.xy += 2.0 * offset * ndcPos.w;
}

void unjitter(inout vec2 ndcPos) {
	vec2 offset = getJitterOffset(ap.time.frames, ap.game.screenSize);
	ndcPos -= 2.0 * offset;// * ndcPos.w;
}

void unjitter(inout vec3 ndcPos) {
	vec2 offset = getJitterOffset(ap.time.frames, ap.game.screenSize);
	ndcPos.xy -= 2.0 * offset;// * ndcPos.w;
}
