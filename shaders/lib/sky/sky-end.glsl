const float endSun_radiusKm = 2000.0;
const float endSun_distanceKm = 20000.0;
const float endSun_axisTilt = 0.8;
const float endSun_rotationSpeed = 0.0128;
const float endSun_luminance = 2000.0;

const float endEarth_radiusKm = 6378.0;
const float endEarth_distanceKm = 40000.0;
const float endEarth_surfaceDepthKm = 600.0;
const float endEarth_axisTilt = 0.0652 * TAU;
const float endEarth_orbitSpeed = -0.002;
const float endEarth_rotationSpeed = 0.0064;
const float endEarth_luminance = 800.0;


vec3 renderEndSun(const in vec3 viewLocalDir, const in vec3 endSunLocalPos, const in float endSunHitDist) {
    vec3 hitPos = viewLocalDir * endSunHitDist;
    vec3 hitNormal = normalize(hitPos - endSunLocalPos);

    mat3 matAxisRot = rotateZ(endSun_axisTilt);
    hitNormal = matAxisRot * hitNormal;

    vec2 erp_uv = DirectionToUV(hitNormal);
    erp_uv.x += endSun_rotationSpeed * ap.time.elapsed;

    vec3 albedo = textureLod(texEndSun, erp_uv, 0).rgb;
    albedo = RgbToLinear(albedo.rgb);

    return albedo * endSun_luminance;
}

vec3 renderEndEarth(const in vec3 viewLocalDir, const in vec3 endEarthLocalPos, const in float endEarthHitDist) {
    vec3 hitPos = viewLocalDir * endEarthHitDist;
    vec3 hitNormal = normalize(hitPos - endEarthLocalPos);

    mat3 matAxisRot = rotateZ(endEarth_axisTilt);
    hitNormal = matAxisRot * hitNormal;

    vec2 erp_uv = DirectionToUV(hitNormal);
    erp_uv.x = 1.0 - erp_uv.x; // TODO: apply to others? or erp math?
    erp_uv.x += endEarth_rotationSpeed * ap.time.elapsed;

    vec4 albedo_height = textureLod(texEarth, erp_uv, 0);
    vec3 smooth_f0_emissive = textureLod(texEarthSpecular, erp_uv, 0).rgb;

    hitPos += endEarth_surfaceDepthKm * albedo_height.a * hitNormal;

    vec3 normal = getSurfaceNormal(hitPos, hitNormal);

    vec3 skyLightAreaDir = GetAreaLightDir(normal, viewLocalDir, -Scene_LocalSunDir, skyLight_AreaDist, skyLight_AreaSize);

    vec3 H = normalize(-viewLocalDir + skyLightAreaDir);

    float NoLm = max(dot(normal, skyLightAreaDir), 0.0);
    float NoVm = max(dot(normal, -viewLocalDir), 0.0);
    float NoHm = max(dot(normal, H), 0.0);
    float LoHm = max(dot(skyLightAreaDir, H), 0.0);
    float VoHm = max(dot(-viewLocalDir, H), 0.0);

    float f0 = smooth_f0_emissive.g;
    float roughness = 1.0 - smooth_f0_emissive.r;
    float emissive = _pow2(smooth_f0_emissive.b);

    vec3 albedo = RgbToLinear(albedo_height.rgb);
    //albedo = normal * 0.5 + 0.5;

    float roughL = _pow2(roughness);
    roughL = max(roughL, 0.08);

    float F = F_schlickRough(VoHm, f0, roughL);
    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
    float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);

    vec3 skyLight = MOON_LUMINANCE * NoLm * (D * albedo + S) * Scene_MoonColor;
    // TODO: use blackbody color?
    const vec3 lightColor = _RgbToLinear(vec3(0.929, 0.855, 0.592));
    skyLight += emissive * endEarth_luminance * lightColor;

    return skyLight;
}
