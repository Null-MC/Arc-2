//bool lineTriangleIntersect(const in vec3 p1, const in vec3 p2, const in vec3 v0, const in vec3 v1, const in vec3 v2, out vec3 coord) {
//    vec3 normal = cross(v1 - v0, v2 - v0);
//    float d = dot(normal, v0);
//
//    float t = (d - dot(normal, p1)) / dot(normal, p2 - p1);
//    if (t < 0.0 || t > 1.0) return false;
//
//    vec3 intersection = fma(p2 - p1, vec3(t), p1);
//
//    coord = vec3(
//        dot(cross(v2 - v1, intersection - v1), normal) / dot(normal, cross(v2 - v1, v0 - v1)),
//        dot(cross(v0 - v2, intersection - v2), normal) / dot(normal, cross(v0 - v2, v1 - v2)),
//        dot(cross(v1 - v0, intersection - v0), normal) / dot(normal, cross(v1 - v0, v2 - v0))
//    );
//
//    return all(greaterThanEqual(coord, vec3(0.0)));
//}

bool lineQuadIntersect(const in vec3 origin, const in vec3 direction, const in vec3 v1, const in vec3 v2, const in vec3 v3, out vec3 hit_pos, out vec2 hit_uv) {
    // TODO: pass in normal rather than recalculate
    vec3 normal = cross(v2 - v1, v3 - v1);

//    float t = dot(normal, direction) / dot(normal, v1 - origin);
    float t = dot(normal, v1 - origin) / dot(normal, direction);
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
