bool shadowPoint_isInBounds(const in vec3 localPos) {
	vec3 sectionOffset = fract(ap.camera.pos / 16.0) * 16.0;
    vec3 sectionPos_abs = abs(floor((sectionOffset + localPos) / 16.0));
    const vec3 pointBoundsMax = vec2(2.0, 1.0).xyx + 0.08;

    return all(lessThanEqual(sectionPos_abs, pointBoundsMax));
}
