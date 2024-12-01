const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);


float InterleavedGradientNoise(const in vec2 pixel) {
    float x = dot(pixel, magic.xy);
    return fract(magic.z * fract(x));
}
