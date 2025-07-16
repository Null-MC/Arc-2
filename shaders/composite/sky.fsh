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

const float earth_radiusKm = 6378.0;
const float earth_distanceKm = 40000.0;
const float earth_surfaceDepthKm = 800.0;
const float earth_axisTilt = 0.8;
const float earth_rotationSpeed = 0.0064;


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

        vec3 skyPos = getSkyPosition(vec3(0.0));
        #ifdef WORLD_OVERWORLD
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

                vec3 skyLightPos = moon_distanceKm * Scene_LocalSunDir;
                float moonHitDist = rayIntersectSphere(skyLightPos, localViewDir, moon_radiusKm);

                if (moonHitDist > 0.0) {
                    vec3 hitPos = localViewDir * -moonHitDist;
                    vec3 hitNormal = normalize(hitPos - skyLightPos);

                    mat3 matMoonRot = rotateZ(moon_axisTilt);
                    hitNormal = matMoonRot * hitNormal;

                    vec2 moon_uv = DirectionToUV(hitNormal);
                    moon_uv.x += moon_rotationSpeed * ap.time.elapsed;
                    vec4 moonData = textureLod(texMoon, moon_uv, 0);
                    vec3 moon_color = RgbToLinear(moonData.rgb);

                    hitPos += moon_surfaceDepthKm * moonData.a * hitNormal;

                    vec3 moonNormal = getSurfaceNormal(hitPos, -hitNormal);

                    const vec3 fakeSunDir = normalize(vec3(0.4, -1.0, 0.2));

                    vec3 H = normalize(-localViewDir + fakeSunDir);

                    float NoLm = max(dot(moonNormal, fakeSunDir), 0.0);
                    float NoVm = max(dot(moonNormal, -localViewDir), 0.0);
                    float NoHm = max(dot(moonNormal, H), 0.0);
                    float LoHm = max(dot(fakeSunDir, H), 0.0);
                    float VoHm = max(dot(-localViewDir, H), 0.0);

                    float F = F_schlickRough(VoHm, moon_f0, moon_roughL);
                    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, moon_roughL) * (1.0 - F);
                    float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, moon_roughL);

                    skyLight += MOON_LUMINANCE * NoLm * (D * moon_color + S) * Scene_SunColor;

                    starLum = 0.0;
                }
            }
            else {
                starLum = 0.0;
            }
        #endif

        #ifdef WORLD_END
            vec3 skyLightPos = earth_distanceKm * Scene_LocalSunDir;
            float earthHitDist = rayIntersectSphere(skyLightPos, localViewDir, earth_radiusKm);

            if (earthHitDist > 0.0) {
                vec3 hitPos = localViewDir * -earthHitDist;
                vec3 hitNormal = normalize(hitPos - skyLightPos);

                mat3 matEarthRot = rotateZ(earth_axisTilt);
                hitNormal = matEarthRot * hitNormal;

                vec2 earth_uv = DirectionToUV(hitNormal);
                earth_uv.x += earth_rotationSpeed * ap.time.elapsed;
                vec4 earthColorHeight = textureLod(texEarth, earth_uv, 0);
                vec3 earthSmoothF0Emissive = textureLod(texEarthSpecular, earth_uv, 0).rgb;
                vec3 earth_color = RgbToLinear(earthColorHeight.rgb);

                hitPos += earth_surfaceDepthKm * earthColorHeight.a * hitNormal;

                vec3 earthNormal = getSurfaceNormal(hitPos, -hitNormal);

                const vec3 fakeSunDir = normalize(vec3(-0.8, -0.2, -0.2));

                vec3 skyLightAreaDir = GetAreaLightDir(earthNormal, localViewDir, fakeSunDir, skyLight_AreaDist, skyLight_AreaSize);

                vec3 H = normalize(-localViewDir + skyLightAreaDir);

                float NoLm = max(dot(earthNormal, skyLightAreaDir), 0.0);
                float NoVm = max(dot(earthNormal, -localViewDir), 0.0);
                float NoHm = max(dot(earthNormal, H), 0.0);
                float LoHm = max(dot(skyLightAreaDir, H), 0.0);
                float VoHm = max(dot(-localViewDir, H), 0.0);

                // TODO: replace f0/rough with spec map
                float earth_f0 = earthSmoothF0Emissive.g;
                float earth_rough = 1.0 - earthSmoothF0Emissive.r;
                float earth_emissive = _pow2(earthSmoothF0Emissive.b);
                float earth_roughL = _pow2(earth_rough);
                earth_roughL = max(earth_roughL, 0.08);

                float F = F_schlickRough(VoHm, earth_f0, earth_roughL);
                float D = SampleLightDiffuse(NoVm, NoLm, LoHm, earth_roughL) * (1.0 - F);
                float S = SampleLightSpecular(NoLm, NoHm, NoVm, F, earth_roughL);

                skyLight += MOON_LUMINANCE * NoLm * (D * earth_color + S) * Scene_SunColor;
                skyLight += earth_emissive * 800.0;

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
