float QuadIntersectDistance(const in vec3 origin, const in vec3 direction, const in vec3 v1, const in vec3 v2, const in vec3 v3) {
    // TODO: pass in normal rather than recalculate
    vec3 normal = cross(v2 - v1, v3 - v1);

    return dot(normal, v1 - origin) / dot(normal, direction);
}

vec2 QuadIntersectUV(const in vec3 hit_pos, const in vec3 v1, const in vec3 v2, const in vec3 v3) {
    vec3 side1 = v2 - v1;
    vec3 side2 = v3 - v1;

    return vec2(
        dot(hit_pos - v1, side1),
        dot(hit_pos - v1, side2)
    ) / vec2(
        dot(side1, side1),
        dot(side2, side2)
    );
}
