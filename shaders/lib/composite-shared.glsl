//const vec3 mainHandViewPos = vec3( 0.25, -0.10, 0.3);
//const vec3 altHandViewPos  = vec3(-0.25, -0.10, 0.3);
const float HandLightOffset_main = 0.2;
const float HandLightOffset_alt = -0.2;


void randomize_reflection(inout vec3 reflectRay, const in vec3 normal, const in float roughL) {
    #ifdef EFFECT_TAA_ENABLED
        vec3 seed = vec3(gl_FragCoord.xy, 1.0 + ap.time.frames);
    #else
        vec3 seed = vec3(gl_FragCoord.xy, 1.0);
    #endif

    vec3 randomVec = normalize(hash33(seed) * 2.0 - 1.0);
    if (dot(randomVec, normal) <= 0.0) randomVec = -randomVec;

    float roughScatterF = 0.25 * (roughL*roughL);
    reflectRay = mix(reflectRay, randomVec, roughScatterF);
    reflectRay = normalize(reflectRay);
}

vec3 GetHandLightPos(const in float offsetX) {
    vec3 pos = vec3(offsetX, -0.15, -0.25);
    pos = mul3(ap.camera.viewInv, pos);
    //pos.y -= 0.32;
    return pos;
}

void GetHandLight(inout vec3 diffuse, inout vec3 specular, const in uint blockId, const in vec3 lightLocalPos,
                  const in vec3 localPos, const in vec3 localViewDir, const in vec3 localTexNormal, const in vec3 localGeoNormal,
                  const in vec3 albedo, const in float f0_metal, const in float roughL) {
//    vec3 lightLocalPos = vec3(0.2, 0.0, 0.0);
    float lightRange = iris_getEmission(blockId);
    vec3 lightColor = iris_getLightColor(blockId).rgb;
    float lightSize = getLightSize(int(blockId));

    //            lightColor = RgbToLinear(lightColor);

//    vec3 light_hsv = RgbToHsv(lightColor);
//    lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));

    // TODO: before or after HSV?
    lightColor = RgbToLinear(lightColor);

    vec3 lightVec = lightLocalPos - localPos;
    float lightDist = length(lightVec);
    vec3 lightDir = lightVec / lightDist;

    float lightAtt = GetLightAttenuation(lightDist, lightRange, lightSize);

    float NoLm = max(dot(localTexNormal, lightDir), 0.0);

    //vec3 diffuse = vec3(0.0);
    if (NoLm > 0.0 && dot(localGeoNormal, lightDir) > 0.0) {
        // TODO: trace hand shadows
        #ifdef HANDLIGHT_TRACE
            vec3 traceStart = voxel_GetBufferPosition(lightLocalPos);
            vec3 traceEnd = voxel_GetBufferPosition(localPos);
            const bool traceSelf = true;
            lightColor *= TraceDDA(traceStart, traceEnd, lightRange, traceSelf);
        #endif

        vec3 H = normalize(lightDir + localViewDir);

        float LoHm = max(dot(lightDir, H), 0.0);
        float NoVm = max(dot(localTexNormal, localViewDir), 0.0);
        float NoHm = max(dot(localTexNormal, H), 0.0);
        float VoHm = max(dot(localViewDir, H), 0.0);

        const bool isUnderWater = false;
        vec3 F = material_fresnel(albedo, f0_metal, roughL, VoHm, isUnderWater);
        vec3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
        vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);

        vec3 lightFinal = NoLm * BLOCK_LUX * lightAtt * lightColor;
        diffuse += D * lightFinal;
        specular += S * lightFinal;
    }
}
