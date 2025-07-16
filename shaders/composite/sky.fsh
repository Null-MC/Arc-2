#version 430 core
#extension GL_ARB_derivative_control: enable

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D solidDepthTex;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;

uniform sampler3D texFogNoise;

#ifdef WORLD_OVERWORLD
    uniform sampler2D texMoon;
#elif defined(WORLD_END)
    uniform sampler2D texEndSun;
    uniform sampler2D texEarth;
    uniform sampler2D texEarthSpecular;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/sampling/erp.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"
#include "/lib/light/brdf.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/transmittance.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


const float moon_radiusKm = 1740.0;
const float moon_distanceKm = 20000.0;
const float moon_surfaceDepthKm = 80.0;
const float moon_rotationSpeed = 0.0064;
const float moon_axisTilt = -0.6;
const float moon_roughL = 0.92;
const float moon_f0 = 0.136;

const float endSun_radiusKm = 2000.0;
const float endSun_distanceKm = 20000.0;
const float endSun_axisTilt = 0.8;
const float endSun_rotationSpeed = 0.0128;
const float endSun_luminance = 2000.0;

const float endEarth_radiusKm = 6378.0;
const float endEarth_distanceKm = 40000.0;
const float endEarth_surfaceDepthKm = 600.0;
const float endEarth_axisTilt = 0.8;
const float endEarth_orbitSpeed = 0.004;
const float endEarth_rotationSpeed = 0.0064;
const float endEarth_luminance = 800.0;


vec3 getSurfaceNormal(const in vec3 position, const in vec3 fallbackNormal) {
    vec3 dX = dFdxFine(position);
    vec3 dY = dFdyFine(position);
    vec3 normal = cross(dX, dY);

    if (lengthSq(normal) > EPSILON) {
        normal = normalize(normal);
    }
    else {
        normal = fallbackNormal;
    }

    return normal;
}

#ifdef WORLD_END
    vec3 renderEndSun(const in vec3 viewLocalDir, const in vec3 endSunLocalPos, const in float endSunHitDist) {
        vec3 hitPos = viewLocalDir * -endSunHitDist;
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
        vec3 hitPos = viewLocalDir * -endEarthHitDist;
        vec3 hitNormal = normalize(hitPos - endEarthLocalPos);

        mat3 matAxisRot = rotateZ(endEarth_axisTilt);
        hitNormal = matAxisRot * hitNormal;

        vec2 erp_uv = DirectionToUV(hitNormal);
        erp_uv.x += endEarth_rotationSpeed * ap.time.elapsed;

        vec4 albedo_height = textureLod(texEarth, erp_uv, 0);
        vec3 smooth_f0_emissive = textureLod(texEarthSpecular, erp_uv, 0).rgb;

        hitPos += endEarth_surfaceDepthKm * albedo_height.a * hitNormal;

        vec3 normal = getSurfaceNormal(hitPos, -hitNormal);

        //const vec3 fakeSunDir = normalize(vec3(-0.8, -0.2, -0.2));

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
        float roughL = _pow2(roughness);
        roughL = max(roughL, 0.08);

        float F = F_schlickRough(VoHm, f0, roughL);
        float D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
        float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);

        vec3 skyLight = MOON_LUMINANCE * NoLm * (D * albedo + S) * Scene_MoonColor;
        // TODO: add blackbody color?
        const vec3 lightColor = _RgbToLinear(vec3(0.929, 0.855, 0.592));
        skyLight += emissive * endEarth_luminance * lightColor;

        return skyLight;
    }
#elif defined(WORLD_SKY_ENABLED)
    vec3 renderMoon(const in vec3 viewLocalDir, const in vec3 moonLocalPos, const in float moonHitDist) {
        vec3 hitPos = viewLocalDir * -moonHitDist;
        vec3 hitNormal = normalize(hitPos - moonLocalPos);

        mat3 matAxisRot = rotateZ(moon_axisTilt);
        hitNormal = matAxisRot * hitNormal;

        vec2 erp_uv = DirectionToUV(hitNormal);
        erp_uv.x += moon_rotationSpeed * ap.time.elapsed;

        vec4 albedo_height = textureLod(texMoon, erp_uv, 0);
        vec3 albedo = RgbToLinear(albedo_height.rgb);

        hitPos += moon_surfaceDepthKm * albedo_height.a * hitNormal;

        vec3 normal = getSurfaceNormal(hitPos, -hitNormal);

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
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;
    vec3 colorFinal = vec3(0.0);

    if (depth == 1.0) {
        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);

        vec3 localViewDir = normalize(localPos);

        #ifdef WORLD_OVERWORLD
            vec3 skyPos = getSkyPosition(vec3(0.0));
            colorFinal = getValFromSkyLUT(texSkyView, skyPos, localViewDir, Scene_LocalSunDir);
        #endif

        vec3 skyLight = vec3(0.0);
        float starLum = STAR_LUMINANCE;
        vec3 starViewDir = getStarViewDir(localViewDir);
        vec3 starColor = GetStarLight(starViewDir);

        #ifdef WORLD_OVERWORLD
            bool intersectsPlanet = rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) >= 0.0;

            if (!intersectsPlanet) {
                float sunF = sun(localViewDir, Scene_LocalSunDir);
                skyLight += sunF * SUN_LUMINANCE * Scene_SunColor;
                starLum *= step(sunF, EPSILON);

                vec3 moonLocalPos = moon_distanceKm * Scene_LocalSunDir;
                float moonHitDist = rayIntersectSphere(moonLocalPos, localViewDir, moon_radiusKm);

                if (moonHitDist > 0.0) {
                    skyLight += renderMoon(localViewDir, moonLocalPos, moonHitDist);
                    starLum = 0.0;
                }
            }
            else {
                starLum = 0.0;
            }
        #endif

        #ifdef WORLD_END
            vec3 endSunPos = endSun_distanceKm * Scene_LocalSunDir;
            float endSunHitDist = rayIntersectSphere(endSunPos, localViewDir, endSun_radiusKm);

            if (endSunHitDist > 0.0) {
                skyLight += renderEndSun(localViewDir, endSunPos, endSunHitDist);
                starLum = 0.0;
            }

            vec3 endEarthLocalDir = normalize(vec3(0.3, 0.0, 0.7));
            mat3 matRot = rotateY(endEarth_orbitSpeed * TAU * ap.time.elapsed);
            matRot *= rotateX(0.8);
            endEarthLocalDir = normalize(endEarthLocalDir * matRot);

            vec3 endEarthPos = endEarth_distanceKm * -endEarthLocalDir;
            float endEarthHitDist = rayIntersectSphere(endEarthPos, localViewDir, endEarth_radiusKm);

            if (endEarthHitDist > 0.0) {
                skyLight += renderEndEarth(localViewDir, endEarthPos, endEarthHitDist);
                starLum = 0.0;
            }
        #endif

        skyLight += starLum * starColor;

        #ifdef WORLD_OVERWORLD
            if (!intersectsPlanet)
                skyLight *= getValFromTLUT(texSkyTransmit, skyPos, localViewDir);
        #endif

        colorFinal += skyLight;
    }

    colorFinal = clamp(colorFinal * BufferLumScaleInv, 0.0, 65000.0);

    outColor = vec4(colorFinal, 1.0);
}
