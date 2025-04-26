#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outDiffuseRT;
layout(location = 1) out vec4 outSpecularRT;

uniform sampler2D TEX_DEPTH;

uniform sampler2D TEX_DEFERRED_COLOR;
uniform usampler2D TEX_DEFERRED_DATA;
uniform sampler2D TEX_DEFERRED_NORMAL;

uniform sampler2D texBlueNoise;

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR || (LIGHTING_MODE == LIGHT_MODE_RT && defined(RT_TRI_ENABLED))
    uniform sampler2D blockAtlas;
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D blockAtlasN;
    uniform sampler2D blockAtlasS;

    uniform sampler2D texSkyView;
    uniform sampler2D texSkyTransmit;
    uniform sampler2D texSkyIrradiance;

    uniform sampler2D TEX_SHADOW;
    uniform sampler2D texFinalPrevious;

    #ifdef SHADOWS_ENABLED
        uniform sampler2DArray shadowMap;
        uniform sampler2DArray solidShadowMap;
        uniform sampler2DArray texShadowColor;
    #endif
#endif

in vec2 uv;

#include "/lib/common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT
    #include "/lib/buffers/light-list.glsl"
#endif

#include "/lib/buffers/voxel-block.glsl"

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/quad-list.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/sampling/blue-noise.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"

#include "/lib/material/material_fresnel.glsl"

#include "/lib/voxel/voxel_common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/voxel/dda.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/voxel/quad-test.glsl"
    #include "/lib/voxel/quad-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT
    #include "/lib/voxel/light-list.glsl"
    #include "/lib/voxel/light-trace.glsl"
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/buffers/scene.glsl"

    #ifdef LPV_ENABLED
        #include "/lib/buffers/sh-lpv.glsl"
    #endif

    #include "/lib/erp.glsl"
    #include "/lib/material/material.glsl"

    #include "/lib/sky/common.glsl"
    #include "/lib/sky/view.glsl"
    #include "/lib/sky/sun.glsl"
    #include "/lib/sky/transmittance.glsl"

    #include "/lib/utility/blackbody.glsl"

    #ifdef LIGHTING_REFLECT_TRIANGLE
        #include "/lib/effects/wsr-quad.glsl"
    #else
        #include "/lib/effects/wsr-block.glsl"
    #endif

    #ifdef SHADOWS_ENABLED
        #include "/lib/shadow/csm.glsl"
        #include "/lib/shadow/sample.glsl"
    #endif

    #ifdef LPV_ENABLED
        #include "/lib/lpv/lpv_common.glsl"
        #include "/lib/lpv/lpv_sample.glsl"
    #endif

    #include "/lib/depth.glsl"
    #include "/lib/effects/ssr.glsl"

    #include "/lib/composite-shared.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(fma(uv, ap.game.screenSize, vec2(0.5)));
    float depth = texelFetch(TEX_DEPTH, iuv, 0).r;

    vec3 diffuseFinal = vec3(0.0);
    vec3 specularFinal = vec3(0.0);

    vec4 albedo = texelFetch(TEX_DEFERRED_COLOR, iuv, 0);

    #ifdef RENDER_TRANSLUCENT
        if (albedo.a < EPSILON) depth = 1.0;
    #endif

    if (depth < 1.0) {
        uvec4 data = texelFetch(TEX_DEFERRED_DATA, iuv, 0);
        vec3 normalData = texelFetch(TEX_DEFERRED_NORMAL, iuv, 0).xyz;

        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);
        vec3 localViewDir = normalize(-localPos);

        vec3 localTexNormal = normalize(normalData * 2.0 - 1.0);

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        vec4 data_g = unpackUnorm4x8(data.g);
        float roughness = data_g.x;
        float f0_metal = data_g.y;
        // float emission = data_g.z;
        // float sss = data_g.w;

        float roughL = roughness*roughness;

        vec3 voxelPos = GetVoxelPosition(localPos);
        vec3 voxelPos_in = voxelPos - 0.02*localGeoNormal;

        #if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            vec4 data_b = unpackUnorm4x8(data.b);
            vec2 lmCoord = data_b.rg;
            //float texOcclusion = data_b.b;
        #endif

        float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

        if (IsInVoxelBounds(voxelPos_in)) {
            #if defined EFFECT_TAA_ENABLED || defined ACCUM_ENABLED
                float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
            #else
                float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
            #endif

            albedo.rgb = RgbToLinear(albedo.rgb);

            #if LIGHTING_MODE == LIGHT_MODE_RT
                ivec3 lightBinPos = ivec3(floor(voxelPos_in / LIGHT_BIN_SIZE));
                int lightBinIndex = GetLightBinIndex(lightBinPos);
                uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                vec3 voxelPos_out = voxelPos + 0.16*localGeoNormal;

                //vec3 jitter = hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;
                vec3 jitter = sample_blueNoise(gl_FragCoord.xy);

                #if RT_MAX_SAMPLE_COUNT > 0
                    uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
                    float bright_scale = ceil(binLightCount / float(RT_MAX_SAMPLE_COUNT));
                #else
                    uint maxSampleCount = binLightCount;
                    const float bright_scale = 1.0;
                #endif

                int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.time.frames)));

                for (int i = 0; i < maxSampleCount; i++) {
                    int i2 = (i + i_offset) % int(binLightCount);

                    uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2];

                    vec3 light_voxelPos = GetVoxelPos(light_voxelIndex) + 0.5;
                    light_voxelPos += jitter*0.125;

                    vec3 light_LocalPos = GetVoxelLocalPos(light_voxelPos);

                    uint blockId = imageLoad(imgVoxelBlock, ivec3(light_voxelPos)).r;


                    float lightRange = iris_getEmission(blockId);
                    vec3 lightColor = iris_getLightColor(blockId).rgb;
                    lightColor = RgbToLinear(lightColor);

                    lightColor *= (lightRange/15.0) * BLOCKLIGHT_BRIGHTNESS;

                    vec3 lightVec = light_LocalPos - localPos;
                    vec2 lightAtt = GetLightAttenuation(lightVec, lightRange);

                    vec3 lightDir = normalize(lightVec);

                    vec3 H = normalize(lightDir + localViewDir);

                    float LoHm = max(dot(lightDir, H), 0.0);
                    float NoLm = max(dot(localTexNormal, lightDir), 0.0);
//                    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

                    if (NoLm == 0.0 || dot(localGeoNormal, lightDir) <= 0.0) continue;
                    float D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);
                    vec3 sampleDiffuse = (NoLm * lightAtt.x * D) * lightColor;

                    float NoHm = max(dot(localTexNormal, H), 0.0);

                    const bool isUnderWater = false;
                    vec3 F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isUnderWater);
                    vec3 S = SampleLightSpecular(NoLm, NoHm, LoHm, F, roughL);
                    vec3 sampleSpecular = lightAtt.x * S * lightColor;

                    vec3 traceStart = light_voxelPos;
                    vec3 traceEnd = voxelPos_out;
                    float traceRange = lightRange;
                    bool traceSelf = false;

                    #ifdef RT_TRI_ENABLED
//                        vec3 traceRay = traceEnd - traceStart;
//                        vec3 direction = normalize(traceRay);
//
//                        vec3 stepDir = sign(direction);
//                        vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(traceStart)) / direction;
//
//                        float closestDist = minOf(nextDist);
//                        traceStart += direction * closestDist;

                        traceRange /= QUAD_BIN_SIZE;
                        traceStart /= QUAD_BIN_SIZE;
                        traceEnd /= QUAD_BIN_SIZE;
                        //traceSelf = true;
                    #endif

                    vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

                    diffuseFinal += sampleDiffuse * shadow_color * bright_scale;
                    specularFinal += sampleSpecular * shadow_color * bright_scale;
                }
            #endif
        }

        #if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            // reflections
            vec3 viewDir = normalize(viewPos);
            vec3 viewNormal = mat3(ap.camera.view) * localTexNormal;
            vec3 reflectViewDir = reflect(viewDir, viewNormal);
            vec3 reflectLocalDir = mat3(ap.camera.viewInv) * reflectViewDir;

            #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                randomize_reflection(reflectLocalDir, localTexNormal, roughness);
            #endif

            vec4 shadow_sss = vec4(vec3(1.0), 0.0);
            #ifdef SHADOWS_ENABLED
                shadow_sss = textureLod(TEX_SHADOW, uv, 0);
            #endif

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);

            // vec3 skyReflectColor = GetSkyColor(vec3(0.0), reflectLocalDir, shadow_sss.rgb, lmCoord.y);
            vec3 skyPos = getSkyPosition(vec3(0.0));
            vec3 skyReflectColor = lmCoord.y * SKY_LUMINANCE * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);

            vec3 reflectSun = SUN_LUMINANCE * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit;
            vec3 reflectMoon = MOON_LUMINANCE * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit;
            skyReflectColor += shadow_sss.rgb * (reflectSun + reflectMoon);

            vec4 reflection = vec4(0.0);
            vec3 reflect_tint = vec3(1.0);

            vec2 reflect_uv, reflect_lmcoord;
            vec3 reflect_voxelPos, reflect_geoNormal;
            vec4 reflect_hitColor;

            if (roughL < 0.86) {
                #ifdef LIGHTING_REFLECT_TRIANGLE
                    // WSR: per-triangle

                    //vec2 reflect_hitCoord;
                    Quad reflect_hitQuad;
                    if (TraceReflection(localPos + 0.1*localGeoNormal, reflectLocalDir, reflect_voxelPos, reflect_uv, reflect_hitColor, reflect_hitQuad)) {
                        reflection = reflect_hitColor;

                        reflect_tint = unpackUnorm4x8(reflect_hitQuad.tint).rgb;

                        vec2 lmcoords[4];
                        GetQuadLightMapCoord(reflect_hitQuad.lmcoord, lmcoords[0], lmcoords[1], lmcoords[2], lmcoords[3]);

//                        reflect_lmcoord = lmcoords[0] * reflect_hitCoord.x;
//                        reflect_lmcoord = fma(lmcoords[1], vec2(reflect_hitCoord.y), reflect_lmcoord);
//                        reflect_lmcoord = fma(lmcoords[2], vec2(reflect_hitCoord.z), reflect_lmcoord);
                        reflect_lmcoord = lmcoords[0];// TODO: also wrong

                        vec3 quad_pos_0 = GetQuadVertexPos(reflect_hitQuad.pos[0]);
                        vec3 quad_pos_1 = GetQuadVertexPos(reflect_hitQuad.pos[1]);
                        vec3 quad_pos_2 = GetQuadVertexPos(reflect_hitQuad.pos[2]);

                        vec3 e1 = normalize(quad_pos_1 - quad_pos_0);
                        vec3 e2 = normalize(quad_pos_2 - quad_pos_0);
                        reflect_geoNormal = normalize(cross(e1, e2));
                    }
                #else
                    // WSR: block-only

                    vec3 reflect_traceTint;
                    VoxelBlockFace blockFace;
                    if (TraceReflection(localPos + 0.1*localGeoNormal, reflectLocalDir, reflect_traceTint, reflect_voxelPos, reflect_geoNormal, reflect_uv, blockFace)) {
                        reflect_tint = GetBlockFaceTint(blockFace.data);
                        reflect_lmcoord = GetBlockFaceLightMap(blockFace.data);

                        iris_TextureInfo tex = iris_getTexture(blockFace.tex_id);
                        reflect_uv = fma(reflect_uv, tex.maxCoord - tex.minCoord, tex.minCoord);

                        vec3 reflectColor = textureLod(blockAtlas, reflect_uv, 0).rgb;
                        reflection = vec4(reflectColor * reflect_traceTint, 1.0);
                    }
                #endif
            }

            if (reflection.a > 0.5) {
                #if MATERIAL_FORMAT != MAT_NONE
                    vec4 reflect_normalData = textureLod(blockAtlasN, reflect_uv, 0);
                    vec4 reflect_specularData = textureLod(blockAtlasS, reflect_uv, 0);
                #endif

                reflection.rgb *= reflect_tint;
                reflection.rgb = RgbToLinear(reflection.rgb);

                reflect_lmcoord = reflect_lmcoord*reflect_lmcoord*reflect_lmcoord;

                #if MATERIAL_FORMAT != MAT_NONE
                    vec3 reflect_localTexNormal = mat_normal(reflect_normalData);
                    float reflect_roughness = mat_roughness(reflect_specularData.r);
                    float reflect_f0_metal = reflect_specularData.g;
                    float reflect_emission = mat_emission(reflect_specularData);
                #else
                    vec3 reflect_localTexNormal = localGeoNormal;
                    float reflect_roughness = 0.92;
                    float reflect_f0_metal = 0.0;
                    float reflect_emission = 0.0;
                #endif

                // TODO: get from TBN
                reflect_localTexNormal = reflect_geoNormal;

                float reflect_roughL = reflect_roughness*reflect_roughness;

                vec3 reflect_localPos = GetVoxelLocalPos(reflect_voxelPos);

                #ifdef SHADOWS_ENABLED
                    int reflect_shadowCascade;
                    vec3 reflect_shadowViewPos = mul3(ap.celestial.view, reflect_localPos);
                    //reflect_shadowViewPos.z += 0.2;
                    vec3 reflect_shadowPos = GetShadowSamplePos(reflect_shadowViewPos, 0.0, reflect_shadowCascade);
                    reflect_shadowPos.z -= GetShadowBias(reflect_shadowCascade);
                    float reflect_shadow = SampleShadow(reflect_shadowPos, reflect_shadowCascade);
                #else
                    float reflect_shadow = 1.0;
                #endif

                vec3 H = normalize(Scene_LocalLightDir + reflectLocalDir);

                float reflect_NoLm = max(dot(reflect_localTexNormal, Scene_LocalLightDir), 0.0);
                float reflect_LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
                float reflect_NoVm = max(dot(reflect_localTexNormal, reflectLocalDir), 0.0);

                vec3 reflect_sunTransmit, reflect_moonTransmit;
                GetSkyLightTransmission(reflect_localPos, reflect_sunTransmit, reflect_moonTransmit);

                float NoL_sun = dot(reflect_localTexNormal, Scene_LocalSunDir);
                float NoL_moon = -NoL_sun;//dot(localTexNormal, -Scene_LocalSunDir);

                vec3 skyLight = SUN_BRIGHTNESS * reflect_sunTransmit * max(NoL_sun, 0.0)
                    + MOON_BRIGHTNESS * reflect_moonTransmit * max(NoL_moon, 0.0);

                vec3 reflect_diffuse = skyLight * reflect_shadow;
                reflect_diffuse *= SampleLightDiffuse(reflect_NoVm, reflect_NoLm, reflect_LoHm, reflect_roughL);

                vec2 skyIrradianceCoord = DirectionToUV(reflect_localTexNormal);
                vec3 reflect_skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
                reflect_diffuse += (SKY_AMBIENT * reflect_lmcoord.y) * reflect_skyIrradiance;

                #if LIGHTING_MODE == LIGHT_MODE_RT
                    ivec3 lightBinPos = ivec3(floor(reflect_voxelPos / LIGHT_BIN_SIZE));
                    int lightBinIndex = GetLightBinIndex(lightBinPos);
                    uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                    vec3 voxelPos_out = reflect_voxelPos + 0.16*reflect_geoNormal;

                    //vec3 jitter = vec3(0.0);//hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;

                    #if RT_MAX_SAMPLE_COUNT > 0
                        uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
                        float bright_scale = ceil(binLightCount / float(RT_MAX_SAMPLE_COUNT));
                    #else
                        uint maxSampleCount = binLightCount;
                        const float bright_scale = 1.0;
                    #endif

                    int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.time.frames)));

                    for (int i = 0; i < maxSampleCount; i++) {
                        int i2 = (i + i_offset) % int(binLightCount);

                        uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2];

                        vec3 light_voxelPos = GetVoxelPos(light_voxelIndex) + 0.5;
                        //light_voxelPos += jitter*0.125;

                        vec3 light_LocalPos = GetVoxelLocalPos(light_voxelPos);

                        uint blockId = imageLoad(imgVoxelBlock, ivec3(light_voxelPos)).r;


                        float lightRange = iris_getEmission(blockId);
                        vec3 lightColor = iris_getLightColor(blockId).rgb;
                        lightColor = RgbToLinear(lightColor);

                        lightColor *= (lightRange/15.0) * BLOCKLIGHT_BRIGHTNESS;

                        vec3 lightVec = light_LocalPos - reflect_localPos;
                        vec2 lightAtt = GetLightAttenuation(lightVec, lightRange);

                        vec3 lightDir = normalize(lightVec);

                        vec3 H = normalize(lightDir + reflectLocalDir);

                        float LoHm = max(dot(lightDir, H), 0.0);
                        float NoLm = max(dot(reflect_localTexNormal, lightDir), 0.0);
                        //                    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

                        if (NoLm == 0.0 || dot(reflect_geoNormal, lightDir) <= 0.0) continue;
                        float D = SampleLightDiffuse(NoVm, NoLm, LoHm, reflect_roughL);
                        vec3 sampleDiffuse = (NoLm * lightAtt.x * D) * lightColor;

                        float NoHm = max(dot(localTexNormal, H), 0.0);

                        const bool reflect_isUnderWater = false;
                        vec3 F = material_fresnel(albedo.rgb, f0_metal, reflect_roughL, NoVm, reflect_isUnderWater);
                        vec3 S = SampleLightSpecular(NoLm, NoHm, LoHm, F, reflect_roughL);
                        vec3 sampleSpecular = lightAtt.x * S * lightColor;

                        vec3 traceStart = light_voxelPos;
                        vec3 traceEnd = voxelPos_out;
                        float traceRange = lightRange;
                        bool traceSelf = false;

                        vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

                        reflect_diffuse += sampleDiffuse * shadow_color * bright_scale;
                        //reflect_specular += sampleSpecular * shadow_color * bright_scale;
                    }
                #elif LIGHTING_MODE == LIGHT_MODE_LPV
                    vec3 voxelSamplePos = fma(reflect_geoNormal, vec3(0.5), reflect_voxelPos);
                    vec3 voxelLight = sample_lpv_linear(voxelSamplePos, reflect_localTexNormal);

                    // TODO: move cloud shadows to RSM sampling!!!
                    reflect_diffuse += voxelLight;// * cloudShadowF;// * SampleLightDiffuse(NoVm, 1.0, 1.0, roughL);
                #else
                    reflect_diffuse += blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * reflect_lmcoord.x);
                #endif

                reflect_diffuse += 0.0016;

                float reflect_metalness = mat_metalness(reflect_f0_metal);
                reflect_diffuse *= 1.0 - reflect_metalness * (1.0 - reflect_roughL);

                #if MATERIAL_EMISSION_POWER != 1
                    reflect_diffuse += pow(reflect_emission, MATERIAL_EMISSION_POWER) * EMISSION_BRIGHTNESS;
                #else
                    reflect_diffuse += reflect_emission * EMISSION_BRIGHTNESS;
                #endif

                skyReflectColor = reflection.rgb * reflect_diffuse;// + reflect_specular;
            }
            else {
                // SSR fallback
                float viewDist = length(localPos);
                //vec3 reflectViewDir = mat3(ap.camera.view) * reflectLocalDir;
                vec3 reflectViewPos = viewPos + 0.5*viewDist*reflectViewDir;
                vec3 reflectClipPos = unproject(ap.camera.projection, reflectViewPos) * 0.5 + 0.5;

                vec3 clipPos = ndcPos * 0.5 + 0.5;
                vec3 reflectRay = normalize(reflectClipPos - clipPos);
                reflection = GetReflectionPosition(TEX_DEPTH, clipPos, reflectRay);

                float maxLod = max(log2(minOf(ap.game.screenSize)) - 2.0, 0.0);
                float screenDist = length((reflection.xy - uv) * (ap.game.screenSize/2.0));
                float roughMip = min(roughness * min(log2(screenDist + 1.0), 6.0), maxLod);
                vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

                skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
            }

            const bool isWet = false;
            float smoothness = 1.0 - roughness;
            vec3 reflectTint = GetMetalTint(albedo.rgb, f0_metal);
            vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
            specularFinal += view_F * skyReflectColor * reflectTint * _pow2(smoothness);
        #endif
    }

    outDiffuseRT = vec4(diffuseFinal, 1.0);
    outSpecularRT = vec4(specularFinal, 1.0);
}
