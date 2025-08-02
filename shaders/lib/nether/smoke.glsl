float SampleSmokeNoise(const in vec3 localPos) {
    float viewDist = length(localPos);

    vec3 worldPos = localPos + ap.camera.pos;
    worldPos.xz *= 0.25;

    float density = 2.0;

    if (viewDist < 128.0) {
        vec3 samplePos = worldPos * 0.043;
        samplePos.y -= 0.02 * ap.time.elapsed;
        float fogNoise = 1.0 - textureLod(texFogNoise, samplePos, 0).r;
        //density *= max(2.0 - 1.8*fogNoise, 0.0);
        density *= smoothstep(0.2, 0.8, fogNoise) * 2.0;
    }

    if (viewDist < 32.0) {
        vec3 samplePos = worldPos * 0.21;
        samplePos.y -= 0.04 * ap.time.elapsed;
        float fogNoise = 1.0 - textureLod(texFogNoise, samplePos, 0).r;
        //density *= max(3.0 - 2.8*fogNoise, 0.0);
        density *= smoothstep(0.2, 0.8, fogNoise) * 2.0;
    }

    return density;
}
