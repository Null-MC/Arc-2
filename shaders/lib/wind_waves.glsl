const float wavingScale = 16.0;
const float wavingHeight = 0.6;
const float Wind_Variation = 0.05 * TAU;

vec3 waving_fbm(const in vec3 worldPos, const in float time_dither) {
    vec2 position = worldPos.xz / wavingScale;

    float iter = 0.0;
    float frequency = 3.0;
    float speed = 1.0;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;

    float time = ap.time.elapsed / 3.6 * 3.0;
    time += Wind_Variation * time_dither;
    
    for (int i = 0; i < 8; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + time * speed;
        x = mod(x, TAU);

        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        position -= force * 0.24;
        height += wave * weight;
        iter += 1.20;
        waveSum += weight;
        weight *= 0.8;
        frequency *= 1.1;
        speed *= 1.3;
    }

    position = ((position * wavingScale) - worldPos.xz) / wavingScale;
    vec3 offset = vec3(position.x, 0.0, position.y);
    return -offset;
}

vec3 GetWavingOffset(const in vec3 originPos, const in vec3 midPos, const in uint blockId) {
    vec3 worldOriginPos = floor(originPos + ap.camera.pos);
    float time_dither = hash13(worldOriginPos);

    float waving_strength = 0.4;
    waving_strength = mix(waving_strength, 1.8, ap.world.rain);
    waving_strength = mix(waving_strength, 3.2, ap.world.thunder);

    vec3 offset_new = waving_fbm(worldOriginPos, time_dither) * waving_strength;
    vec3 offsetFinal = vec3(0.0);

    if (iris_hasTag(blockId, TAG_WAVING_FULL)) {
        // no attach
        offsetFinal = offset_new;
    }
    else if (iris_hasTag(blockId, TAG_FOLIAGE_GROUND)) {
        // ground attach
        float attach_dist = 0.5 - midPos.y;

        if (attach_dist > 0.0) {
            vec3 new_pos = vec3(offset_new.x, attach_dist, offset_new.z);

            new_pos *= attach_dist / length(new_pos);
            new_pos.y -= attach_dist;

            offsetFinal = new_pos;
        }
    }

    return offsetFinal;
}
