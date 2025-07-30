float cloudHeight2 = cloudHeight + 240.0;


float SampleCloudDensity(const in vec3 worldPos) {
    float time = mod(ap.time.elapsed * 0.006, 1.0);
    vec2 wind = 9.0 * vec2(0.7, 0.3) * ap.time.elapsed;

    vec2 samplePos = worldPos.xz + wind;
    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.00013, time).xzy, 0).r;
    detailLow *= 1.0 - textureLod(texFogNoise, vec3(samplePos * 0.00064, time).xzy, 0).r;
    float detailHigh = 1.0 - textureLod(texFogNoise, vec3(samplePos * 0.005, time+0.2).xzy, 0).r;
    float cloud_sample = detailLow + 0.06*(detailHigh);

    float cloud_density = 0.6;
    cloud_density = mix(cloud_density, 2.2, World_SkyWetness);
    //cloud_density = mix(cloud_density, 2.2, ap.world.thunder);

    float cloud_threshold = 1.0 - Sky_CloudCoverage;
    cloud_threshold = mix(cloud_threshold, 0.19, World_SkyWetness);
    //cloud_threshold = mix(cloud_threshold, 0.15, ap.world.thunder);

    float sample_density = smoothstep(_pow2(cloud_threshold), 1.0, cloud_sample);

    return pow(sample_density, 0.5) * cloud_density;
}

//float SampleCloudDensity2(const in vec3 worldPos) {
//    float time = mod(ap.time.elapsed * 0.006, 1.0);
//    vec2 wind = 3.0 * vec2(0.7, 0.3) * ap.time.elapsed;
//
//    vec2 samplePos = worldPos.xz + wind;
//    float detailLow  = textureLod(texFogNoise, vec3(samplePos * 0.00016, time).xzy, 0).r;
//    float cloud_sample = detailLow;
//
//    float cloud_density = mix(1.0, 40.0, ap.world.rain);
//    float cloud_threshold = mix(0.16, 0.02, ap.world.rain);
//    return smoothstep(cloud_threshold, 1.0, cloud_sample) * cloud_density;
//}
