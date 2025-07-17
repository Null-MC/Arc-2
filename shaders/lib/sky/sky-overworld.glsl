//const float moon_radiusKm = 1740.0;
//const float moon_distanceKm = 20000.0;
const float moon_surfaceDepthKm = 80.0;
const float moon_rotationSpeed = 0.0064;
const float moon_axisTilt = -0.6;
const float moon_roughL = 0.92;
const float moon_f0 = 0.136;


vec3 renderMoon(const in vec3 viewLocalDir, const in vec3 moonLocalPos, const in float moonHitDist, const in bool isReflection) {
    vec3 hitPos = viewLocalDir * moonHitDist;
    vec3 hitNormal = normalize(hitPos - moonLocalPos);
    if (isReflection) hitNormal = -hitNormal;

    mat3 matAxisRot = rotateZ(moon_axisTilt);
    hitNormal = matAxisRot * hitNormal;

    vec2 erp_uv = DirectionToUV(hitNormal);
    erp_uv.x += moon_rotationSpeed * ap.time.elapsed;

    vec4 albedo_height = textureLod(texMoon, erp_uv, 0);
    vec3 albedo = RgbToLinear(albedo_height.rgb);

    hitPos += moon_surfaceDepthKm * albedo_height.a * hitNormal;

    vec3 normal = getSurfaceNormal(hitPos, hitNormal);
    if (isReflection) normal = -normal;

    const vec3 fakeSunDir = normalize(vec3(0.4, -1.0, 0.2));

    vec3 H = normalize(-viewLocalDir + fakeSunDir);

    float NoLm = max(dot(normal, fakeSunDir), 0.0);
    float NoVm = max(dot(normal, -viewLocalDir), 0.0);
    float NoHm = max(dot(normal, H), 0.0);
    float LoHm = max(dot(fakeSunDir, H), 0.0);
    float VoHm = max(dot(-viewLocalDir, H), 0.0);

    float F = F_schlickRough(VoHm, moon_f0, moon_roughL);
    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, moon_roughL) * (1.0 - F);
    float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, moon_roughL);

    return MOON_LUMINANCE * NoLm * (D * albedo + S) * Scene_SunColor;
}
