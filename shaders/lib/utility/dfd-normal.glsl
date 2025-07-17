vec3 getSurfaceNormal(const in vec3 position, const in vec3 fallbackNormal) {
    #ifdef GL_ARB_derivative_control
        vec3 dX = dFdxFine(position);
        vec3 dY = dFdyFine(position);
    #else
        vec3 dX = dFdx(position);
        vec3 dY = dFdy(position);
    #endif

    vec3 normal = cross(dX, dY);

    if (lengthSq(normal) > EPSILON) {
        normal = normalize(normal);
    }
    else {
        normal = fallbackNormal;
    }

    return normal;
}
