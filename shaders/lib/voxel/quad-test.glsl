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


bool lineQuadIntersect(const in vec3 origin, const in vec3 direction, const in vec3 v1, const in vec3 v2, const in vec3 v3, out vec3 hit_pos, out vec2 hit_uv) {
    // TODO: pass in normal rather than recalculate
    vec3 normal = cross(v2 - v1, v3 - v1);

    float t = dot(normal, v1 - origin) / dot(normal, direction);
    if (t < -0.0001) return false;

    hit_pos = origin + direction * t;

    vec3 side1 = v2 - v1;
    vec3 side2 = v3 - v1;

    hit_uv = vec2(
        dot(hit_pos - v1, side1),
        dot(hit_pos - v1, side2)
    ) / vec2(
        dot(side1, side1),
        dot(side2, side2)
    );

    return clamp(hit_uv, 0.0, 1.0) == hit_uv;
}
