// Units are in megameters.
const float groundRadiusMM = 8.371;
const float atmosphereRadiusMM = 0.040 + groundRadiusMM;

const vec3 groundAlbedo = vec3(0.3);

// These are per megameter.
const vec3 rayleighScatteringBase = vec3(6.605, 12.344, 29.412);
const float rayleighAbsorptionBase = 0.0;

const float mieScatteringBase = 3.996;
const float mieAbsorptionBase = 4.4;

const vec3 ozoneAbsorptionBase = vec3(2.291, 1.540, 0.000);//*1e-3;

const float Sky_MinLight = 2.5;


float safeacos(const float x) {
    return acos(clamp(x, -1.0, 1.0));
}

vec3 getSkyPosition(const in vec3 localPos) {
    vec3 skyPos = localPos;
    skyPos.y = ap.camera.pos.y + localPos.y - Scene_SkyFogSeaLevel;
    //skyPos /= (ATMOSPHERE_MAX - SKY_SEA_LEVEL);
    //skyPos.y *= 10.0;

    //skyPos *= (atmosphereRadiusMM - groundRadiusMM);
    skyPos *= 0.000001;
    skyPos.y = max(skyPos.y, 0.0002) + groundRadiusMM;

    return skyPos;
}

float getMiePhase(const in float cosTheta, const in float g) {
    float g2 = g*g;

    float num = (1.0 - g2) * (1.0 + cosTheta*cosTheta);
    float denom = (2.0 + g2) * pow((1.0 + g2 - 2.0*g*cosTheta), 1.5);

    const float scale = 3.0 / (8.0*PI);
    return scale * (num / denom);
}

float getMiePhase(float cosTheta) {
    //const float g = 0.8;
    //return getMiePhase(cosTheta, g);

    return DHG(cosTheta, -0.5, 0.8, 0.5);
}

float getRayleighPhase(float cosTheta) {
    const float k = 3.0 / (16.0*PI);
    return k * (1.0 + _pow2(cosTheta));
}

//void getScatteringValues(vec3 pos, float stepDist, float sampleDensity, out vec3 rayleighScattering, out float mieScattering, out vec3 extinction) {
//    float altitudeKM = (length(pos)-groundRadiusMM) * 1000.0;
//
//    // Note: Paper gets these switched up.
//    float rayleighDensity = stepDist * 0.0001 * exp(-altitudeKM/8.0);
//    float mieDensity = stepDist*sampleDensity * 0.0001 * exp(-altitudeKM/1.2);
//
//    rayleighScattering = rayleighScatteringBase*rayleighDensity;
//    float rayleighAbsorption = rayleighAbsorptionBase*rayleighDensity;
//
//    mieScattering = mieScatteringBase*mieDensity;
//    float mieAbsorption = mieAbsorptionBase*mieDensity;
//
//    vec3 ozoneAbsorption = ozoneAbsorptionBase * max(0.0, 1.0 - abs(altitudeKM-25.0)/15.0);
//
//    extinction = rayleighScattering + rayleighAbsorption + mieScattering + mieAbsorption + ozoneAbsorption;
//}

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
    uv = saturate(uv);

    return textureLod(tex, uv, 0).rgb;
}

vec3 getValFromMultiScattLUT(sampler2D tex, vec3 pos, vec3 sunDir) {
    float height = length(pos);
    vec3 up = pos / height;

    vec2 uv;
    uv.x = dot(sunDir, up) * 0.5 + 0.5;
    uv.y = (height - groundRadiusMM) / (atmosphereRadiusMM - groundRadiusMM);
    uv = saturate(uv);

    return textureLod(tex, uv, 0).rgb * 1000.0;
}
