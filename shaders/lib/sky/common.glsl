// Units are in megameters.
const float groundRadiusMM = 6.360;
const float atmosphereRadiusMM = 6.460;

const vec3 groundAlbedo = vec3(0.3);

// These are per megameter.
const vec3 rayleighScatteringBase = vec3(5.802, 13.558, 33.1);
const float rayleighAbsorptionBase = 0.0;

const float mieScatteringBase = 3.996;
const float mieAbsorptionBase = 4.4;

const vec3 ozoneAbsorptionBase = vec3(0.650, 1.881, .085);


float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

vec3 getSkyPosition(const in vec3 localPos) {
    vec3 skyPos = localPos;
    skyPos.y += max(cameraPos.y - SEA_LEVEL, 0.0);
    skyPos /= (ATMOSPHERE_MAX - SEA_LEVEL);

    skyPos *= (atmosphereRadiusMM - groundRadiusMM);
    skyPos.y += groundRadiusMM;

    return skyPos;
}

float getMiePhase(float cosTheta) {
    const float g = 0.8;
    const float scale = 3.0 / (8.0*PI);
    
    float g2 = g*g;
    float num = (1.0 - g2) * (1.0 + cosTheta*cosTheta);
    float denom = (2.0 + g2) * pow((1.0 + g2 - 2.0*g*cosTheta), 1.5);
    
    return scale * (num/denom);
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0 / (16.0*PI);
    return k * (1.0 + cosTheta*cosTheta);
}

void getScatteringValues(vec3 pos, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) {
    float altitudeKM = (length(pos)-groundRadiusMM) * 1000.0;

    // Note: Paper gets these switched up.
    float rayleighDensity = exp(-altitudeKM/8.0);
    float mieDensity = exp(-altitudeKM/1.2);
    
    rayleighScattering = rayleighScatteringBase*rayleighDensity;
    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;
    
    mieScattering = mieScatteringBase*mieDensity;
    float mieAbsorption = mieAbsorptionBase*mieDensity;
    
    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);
    
    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
}

// From https://gamedev.stackexchange.com/questions/96459/fast-ray-sphere-collision-code.
float rayIntersectSphere(vec3 ro, vec3 rd, float rad) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - rad*rad;
    if (c > 0.0f && b > 0.0) return -1.0;

    float discr = b*b - c;
    if (discr < 0.0) return -1.0;

    // Special case: inside sphere, use far discriminant
    if (discr > b*b) return (-b + sqrt(discr));
    return -b - sqrt(discr);
}

vec3 getValFromTLUT(sampler2D tex, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;

    vec2 uv;
    uv.x = dot(sunDir, up) * 0.5 + 0.5;
    uv.y = (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM);
    uv = clamp(uv, 0.0, 1.0);

    return textureLod(tex, uv, 0).rgb;
}

vec3 getValFromMultiScattLUT(sampler2D tex, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;

    vec2 uv;
    uv.x = dot(sunDir, up) * 0.5 + 0.5;
    uv.y = (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM);
    uv = clamp(uv, 0.0, 1.0);

    return textureLod(tex, uv, 0).rgb;
}
