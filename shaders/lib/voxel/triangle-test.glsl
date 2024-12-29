bool lineTriangleIntersect(const in vec3 p1, const in vec3 p2, const in vec3 v0, const in vec3 v1, const in vec3 v2, out vec3 coord) {
    vec3 normal = cross(v1 - v0, v2 - v0);
    float d = dot(normal, v0);

    float t = (d - dot(normal, p1)) / dot(normal, p2 - p1);
    if (t < 0.0 || t > 1.0) return false;

    vec3 intersection = p1 + t * (p2 - p1);

    coord = vec3(
        dot(cross(v2 - v1, intersection - v1), normal) / dot(normal, cross(v2 - v1, v0 - v1)),
        dot(cross(v0 - v2, intersection - v2), normal) / dot(normal, cross(v0 - v2, v1 - v2)),
        dot(cross(v1 - v0, intersection - v0), normal) / dot(normal, cross(v1 - v0, v2 - v0))
    );

    return all(greaterThanEqual(coord, vec3(0.0)));
}
