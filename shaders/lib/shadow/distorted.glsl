const float Shadow_DistortF = 0.08;


vec3 shadowDistort(const in vec3 pos) {
    float factor = length(pos.xy) + Shadow_DistortF;
    return vec3(pos.xy / factor, pos.z);
}
