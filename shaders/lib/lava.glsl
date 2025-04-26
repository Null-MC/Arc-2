const float Lava_HeightScale = 0.1;


void RandomizeNormal(inout vec3 normal, const in vec2 texPos, const in float maxTheta) {
    vec3 randomNormal = hash32(texPos) * 2.0 - 1.0;
    randomNormal.z *= sign(randomNormal.z);
    normal = mix(normal, randomNormal, maxTheta);
    normal = normalize(normal);
}

float LavaFBM(vec3 texPos) {
    float accum = 0.0;
    float weight = 1.0;
    float maxWeight = 0.0;
    for (int i = 0; i < 4; i++) {
        float p = textureLod(texFogNoise, texPos.xzy, 0).r;
        accum += p * weight;
        maxWeight += weight;

        texPos *= 3.0;
        weight *= 0.7;
    }

    return accum / maxWeight;
}

const float LAVA_SPEED = 16.0; // [12 24]

void ApplyLavaMaterial(out vec3 albedo, out vec3 normal, out float roughness, out float emission, const in vec3 geoViewNormal, const in vec3 worldPos, const in vec3 viewPos) {
    //albedo = vec3(1.0);
    normal = geoViewNormal;

    //float time = frameTimeCounter / 3600.0;
    float time = ap.time.elapsed / 3600.0;
    vec3 texPos = worldPos.xzy * vec3(0.0125, 0.0125, 0.008);
    texPos += vec3(0.05, 0.05, 1.00) * fract(time * LAVA_SPEED);

    vec3 upViewDir = ap.camera.view[1].xyz;// vec3(0.0, 1.0, 0.0);//normalize(upPosition);
    float NoU = abs(dot(geoViewNormal, upViewDir));
    float NoU_inv = 1.0 - NoU;

    float pressure = LavaFBM(texPos);
    //pressure = pow(pressure, 0.75);
    float coolF = 0.08 * NoU;
    float heatF = 1.75;// + 0.05*NoU_inv;
    float heatP = 6.0;// - 0.5*NoU_inv;// + 1.0 * NoU;

    float t = min(pow(max(pressure - coolF, 0.0) * heatF, heatP), 1.0);

    //t = t*t;

    float ti = 1.0 - t;

    float temp = 800.0 + 4000.0 * t;
    albedo = 0.001 + blackbody(temp) * t;// * 2.0;
    roughness = mix(1.0, 0.2, ti*ti*ti);//1.0 - 0.28 * pow(1.0 - t, 2.0);
    emission = saturate(1.2*t);
    //f0 = 0.06 - 0.02 * t;
    //hcm = -1;

    float heightMax = 0.8 - 0.22 * NoU;
    float height = smoothstep(0.34, heightMax, 1.0 - pressure) - pow(pressure, 0.7);
    vec3 viewPosFinal = viewPos + geoViewNormal * (Lava_HeightScale * height);
    vec3 dX = dFdx(viewPosFinal);
    vec3 dY = dFdy(viewPosFinal);

    if (dX != vec3(0.0) && dY != vec3(0.0)) {
        vec3 n = cross(dX, dY);
        if (n != vec3(0.0))
            normal = normalize(n);

//         vec2 nTex = fract(worldPos.xz) * 128.0;
//         nTex = floor(nTex + 0.5) / 128.0;
//         RandomizeNormal(normal, nTex, ti);
    }
}
