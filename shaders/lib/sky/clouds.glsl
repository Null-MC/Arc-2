float cloudHeight2 = cloudHeight + 240.0;


float SampleCloudDensity(const in vec3 worldPos) {
    float time = mod(ap.time.elapsed * 0.006, 1.0);
    vec2 wind = 3.0 * vec2(0.7, 0.3) * ap.time.elapsed;

    vec2 samplePos = worldPos.xz + wind;
    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.0004, time).xzy, 0).r;
    float detailHigh = textureLod(texFogNoise, vec3(samplePos * 0.0064, time+0.2).xzy, 0).r;
    float cloud_sample = detailLow + 0.06*(detailHigh);

    float cloud_density = mix(0.05, 0.20, ap.world.rainStrength);
    float cloud_threshold = mix(0.32, 0.08, ap.world.rainStrength);
    return smoothstep(cloud_threshold, 1.0, cloud_sample) * cloud_density;
    // return pow(max(cloud_sample - 0.3, 0.0) / (7.0/10.0), 0.5) * cloud_density;
}

float SampleCloudDensity2(const in vec3 worldPos) {
    float time = mod(ap.time.elapsed * 0.006, 1.0);
    vec2 wind = 3.0 * vec2(0.7, 0.3) * ap.time.elapsed;

    vec2 samplePos = worldPos.xz + wind;
    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.00016, time).xzy, 0).r;
    float cloud_sample = detailLow;

    float cloud_density = mix(1.0, 40.0, ap.world.rainStrength);
    float cloud_threshold = mix(0.16, 0.02, ap.world.rainStrength);
    return smoothstep(cloud_threshold, 1.0, cloud_sample) * cloud_density;
    // return pow(max(cloud_sample - 0.3, 0.0) / (7.0/10.0), 0.5) * cloud_density;
}
