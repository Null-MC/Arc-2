// based on: https://www.shadertoy.com/view/MdXyzX

const float DRAG_MULT = 0.09;

const float WaterWaveSurfaceOffset = 0.6;
const int WaterWaveOctaveMin = 15;
const int WaterWaveOctaveMax = 15;

const vec3 WaterWaveScaleF = vec3(1.5, 3.0, 1.5);

vec2 waveDx(const in vec2 position, const in vec2 direction, const in float frequency, const in float timeshift) {
    float x = dot(direction, position) * frequency + timeshift;
    float xMod = mod(x, TAU);

    float wave = exp(sin(xMod) - 1.0);
    float dx = wave * cos(xMod);
    return vec2(wave, -dx);
}

vec3 GetWaveHeight(const in vec3 position, const in float skyLight, const in float time, const in int iterations) {
    float iter = 0.0;           // this will help generating well distributed wave directions
    float weight = 1.0;         // weight in final sum for the wave, this will change every iteration
    float frequency = 1.0;      // frequency of the wave, this will change every iteration
    float timeMultiplier = 2.5; // time multiplier for the wave, this will change every iteration
    
    vec3 wavePos = position * WaterWaveScaleF;
    float weightSum = 0.0;
    float valueSum = 0.0;

    for (int i = 0; i < iterations; i++) {
        float iterMod = mod(iter, TAU);
        vec2 p = vec2(sin(iterMod), cos(iterMod));

        vec2 octave = waveDx(wavePos.xz, p, frequency, time * timeMultiplier);
        wavePos.xz += p * octave.y * weight * DRAG_MULT;

        valueSum += octave.x * weight;
        weightSum += weight;

        iter += 1232.399963;
        timeMultiplier *= 1.07;
        frequency *= 1.18;
        weight *= 0.82;
    }

    float heightDelta = valueSum / max(weightSum, 0.000001);
    wavePos.y += heightDelta*heightDelta;
    wavePos.y -= WaterWaveSurfaceOffset;

    vec3 delta = wavePos / WaterWaveScaleF - position;
    return delta;
}
