float SampleCloudDensity(const in vec3 worldPos) {
    float time = mod(timeCounter * 0.006, 1.0);
    vec2 wind = 3.0 * vec2(0.7, 0.3) * timeCounter;

    vec2 samplePos = worldPos.xz + wind;
    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.0004, time).xzy, 0).r;
    float detailHigh = textureLod(texFogNoise, vec3(samplePos * 0.0064, time+0.2).xzy, 0).r;
    float cloud_sample = detailLow + 0.06*(detailHigh);

    float cloud_density = mix(8.0, 200.0, rainStrength);
    float cloud_threshold = mix(0.28, 0.24, rainStrength);
    return smoothstep(cloud_threshold, 1.0, cloud_sample) * cloud_density;
    // return pow(max(cloud_sample - 0.3, 0.0) / (7.0/10.0), 0.5) * cloud_density;
}

float SampleCloudDensity2(const in vec3 worldPos) {
    float time = mod(timeCounter * 0.006, 1.0);
    vec2 wind = 3.0 * vec2(0.7, 0.3) * timeCounter;

    vec2 samplePos = worldPos.xz + wind;
    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.00016, time).xzy, 0).r;
    float cloud_sample = detailLow;

    float cloud_density = mix(16.0, 200.0, rainStrength);
    float cloud_threshold = mix(0.16, 0.24, rainStrength);
    return smoothstep(cloud_threshold, 1.0, cloud_sample) * cloud_density;
    // return pow(max(cloud_sample - 0.3, 0.0) / (7.0/10.0), 0.5) * cloud_density;
}
