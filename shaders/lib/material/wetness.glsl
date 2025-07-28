float GetSkyWetness(const in vec3 localPos, const in vec3 localNormal, const in float lmcoord_y) {
    const vec3 worldUp = vec3(0.0, 1.0, 0.0);
    float upF = smoothstep(-0.2, 0.2, dot(localNormal, worldUp));

    float sky_wetness = World_GroundWetness;//max(ap.world.rain, ap.world.thunder);
    sky_wetness *= smoothstep(0.90, 0.96, lmcoord_y) * upF;

    float puddle = 0.7;
    float dist = length(localPos);
    if (dist < 80) {
        vec3 samplePos = vec3(0.04 * (localPos.xz + ap.camera.pos.xz), 0.5).xzy;
        float noise = 1.0 - textureLod(texFogNoise, samplePos, 0).r;
        noise = saturate(noise * 1.4 + 0.2);

        float distF = smoothstep(40.0, 80.0, dist);
        puddle = mix(noise, puddle, distF);
    }

    sky_wetness *= puddle;
    return sky_wetness;
}

void ApplyWetness_albedo(inout vec3 albedo, const in float porosity, const in float wetness) {
    float wetnessDarkenF = smoothstep(0.08, 0.9, wetness) * porosity;
    albedo.rgb *= 1.0 - 0.2*wetnessDarkenF;
    albedo.rgb = pow(albedo.rgb, vec3(1.0 + 1.2*wetnessDarkenF));
}

void ApplyWetness_texNormal(inout vec3 localTexNormal, const in vec3 localGeoNormal, const in float porosity, const in float wetness) {
    localTexNormal = mix(localTexNormal, localGeoNormal, wetness);
    localTexNormal = normalize(localTexNormal);
}

void ApplyWetness_roughness(inout float roughL, const in float porosity, const in float wetness) {
    //roughL = mix(roughL, 0.04, wetness * (1.0 - 0.6*porosity));

    roughL = mix(roughL, 0.02, wetness);
}
