const ivec3 pointBoundsMax = ivec2(4, 3).xyx;


bool shadowPoint_isInBounds(const in vec3 localPos) {
	vec3 sectionOffset = fract(ap.camera.pos / 16.0) * 16.0;
    vec3 sectionPos_abs = abs(floor((sectionOffset + localPos) / 16.0));
    const vec3 _max = pointBoundsMax + 0.08;

    return all(lessThanEqual(sectionPos_abs, _max));
}
