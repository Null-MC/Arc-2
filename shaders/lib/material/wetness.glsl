void ApplyWetness_albedo(inout vec3 albedo, const in float porosity, const in float wetness) {
    float wetnessDarkenF = wetness*porosity;
    albedo.rgb *= 1.0 - 0.2*wetnessDarkenF;
    albedo.rgb = pow(albedo.rgb, vec3(1.0 + 1.2*wetnessDarkenF));
}

void ApplyWetness_roughL(inout float roughL, const in float wetness) {
    roughL = mix(roughL, 0.04, wetness);
}
