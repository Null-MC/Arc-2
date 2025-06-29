const ivec3 pointBoundsMax = ivec3(3, 2, 3);


bool shadowPoint_isInBounds(const in vec3 localPos) {
	vec3 sectionOffset = fract(ap.camera.pos / 16.0) * 16.0;
    vec3 sectionPos_abs = abs(floor((sectionOffset + localPos) / 16.0));
    const vec3 _max = pointBoundsMax + 0.08;

    return all(lessThanEqual(sectionPos_abs, _max));
}

uint getPointLightBlock(const in uint lod, const in uint index) {
    uint blockId;
    switch (lod) {
        case 0u:
            blockId = ap.point.block0[index];
            break;
        case 1u:
            blockId = ap.point.block1[index];
            break;
        case 2u:
            blockId = ap.point.block2[index];
            break;
    }
    return blockId;
}

vec3 getPointLightPos(const in uint lod, const in uint index) {
    vec3 lightPos;
    switch (lod) {
        case 0u:
            lightPos = ap.point.pos0[index].xyz;
            break;
        case 1u:
            lightPos = ap.point.pos1[index].xyz;
            break;
        case 2u:
            lightPos = ap.point.pos2[index].xyz;
            break;
    }
    return lightPos;
}
