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
uniform sampler3D texFogNoise;

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR || (LIGHTING_MODE == LIGHT_MODE_RT && defined(RT_TRI_ENABLED))
    uniform sampler2D blockAtlas;
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D blockAtlasN;
    uniform sampler2D blockAtlasS;

    uniform sampler2D texSkyView;
    uniform sampler2D texSkyTransmit;
    uniform sampler2D texSkyIrradiance;

    #ifdef WORLD_END
        uniform sampler2D texEndSun;
        uniform sampler2D texEarth;
        uniform sampler2D texEarthSpecular;
    #elif defined(WORLD_SKY_ENABLED)
        uniform sampler2D texMoon;
    #endif

    uniform sampler2D TEX_SHADOW;
    uniform sampler2D texFinalPrevious;

    #ifdef SHADOWS_ENABLED
        uniform sampler2DArray shadowMap;
        uniform sampler2DArray solidShadowMap;
        uniform sampler2DArray texShadowBlocker;
        uniform sampler2DArray texShadowColor;
    #endif

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
        uniform samplerCubeArrayShadow pointLightFiltered;

        #ifdef LIGHTING_SHADOW_PCSS
            uniform samplerCubeArray pointLight;
        #endif
    #endif

    #ifdef FLOODFILL_ENABLED
        uniform sampler3D texFloodFill;
        uniform sampler3D texFloodFill_alt;
    #endif
#endif

in vec2 uv;

#include "/lib/common.glsl"

#ifndef VOXEL_PROVIDED
    #include "/lib/buffers/voxel-block.glsl"
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/buffers/voxel-block-face.glsl"
#endif

#ifdef LIGHT_LIST_ENABLED
    #include "/lib/buffers/light-list.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/quad-list.glsl"
#endif

#include "/lib/utility/hsv.glsl"
#include "/lib/hg.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/noise/blue.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"
#include "/lib/light/brdf.glsl"

#include "/lib/material/material_fresnel.glsl"

#include "/lib/voxel/voxel-common.glsl"
#include "/lib/voxel/voxel-sample.glsl"

#ifdef LIGHT_LIST_ENABLED
    #include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/voxel/dda.glsl"
#endif

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/voxel/quad-test.glsl"
    #include "/lib/voxel/quad-list.glsl"
#endif

//#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
//    #include "/lib/shadow-point/common.glsl"
//    #include "/lib/shadow-point/sample-common.glsl"
//    #include "/lib/shadow-point/sample-geo.glsl"
//#elif LIGHTING_MODE == LIGHT_MODE_RT
//    //#include "/lib/voxel/light-list.glsl"
//#endif

#include "/lib/light/meta.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT || defined(HANDLIGHT_TRACE)
    #include "/lib/voxel/light-trace.glsl"
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/buffers/scene.glsl"

    #ifdef LIGHTING_GI_ENABLED
        #include "/lib/buffers/wsgi.glsl"
    #endif

    #include "/lib/sampling/erp.glsl"

    #include "/lib/utility/blackbody.glsl"
    #include "/lib/utility/matrix.glsl"
    #include "/lib/utility/dfd-normal.glsl"

    #include "/lib/material/material.glsl"
    #include "/lib/material/wetness.glsl"

    #include "/lib/sky/common.glsl"
    #include "/lib/sky/view.glsl"
    #include "/lib/sky/sun.glsl"
    #include "/lib/sky/stars.glsl"
    #include "/lib/sky/irradiance.glsl"
    #include "/lib/sky/transmittance.glsl"

    #ifdef WORLD_END
        #include "/lib/sky/sky-end.glsl"
    #elif defined(WORLD_SKY_ENABLED)
        #include "/lib/sky/sky-overworld.glsl"
    #endif

    #include "/lib/sky/render.glsl"

    #include "/lib/light/volumetric.glsl"

    #ifdef LIGHTING_REFLECT_TRIANGLE
        #include "/lib/voxel/wsr-quad.glsl"
    #else
        #include "/lib/voxel/wsr-block.glsl"
    #endif

    #ifdef SHADOWS_ENABLED
        #ifdef SHADOW_DISTORTION_ENABLED
            #include "/lib/shadow/distorted.glsl"
        #endif

        #include "/lib/shadow/csm.glsl"
        #include "/lib/shadow/sample.glsl"
    #endif

    #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
        #include "/lib/sky/density.glsl"
        #include "/lib/sky/clouds.glsl"
        #include "/lib/shadow/clouds.glsl"
    #endif

    #ifdef LIGHTING_GI_ENABLED
        #include "/lib/voxel/wsgi-common.glsl"
        #include "/lib/voxel/wsgi-sample.glsl"
    #endif

    #include "/lib/sampling/depth.glsl"
    #include "/lib/effects/ssr.glsl"

    #include "/lib/lightmap/sample.glsl"

    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
        #include "/lib/shadow-point/common.glsl"
        #include "/lib/shadow-point/sample-common.glsl"
        #include "/lib/shadow-point/sample-geo.glsl"
    #endif

    #ifdef FLOODFILL_ENABLED
        #include "/lib/voxel/floodfill-sample.glsl"
    #endif

    #include "/lib/composite-shared.glsl"
#endif

#include "/lib/taa_jitter.glsl"


void main() {
    vec2 subpixelOffset = vec2(0.0);//getJitterOffset(ap.time.frames, vec2(0.25));

    ivec2 iuv = ivec2(fma(uv, ap.game.screenSize, subpixelOffset));
    float depth = texelFetch(TEX_DEPTH, iuv, 0).r;

    vec3 diffuseFinal = vec3(0.0);
    vec3 specularFinal = vec3(0.0);
    float reflectDist = 0.0;

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

        vec4 data_b = unpackUnorm4x8(data.b);
        vec2 lmCoord = data_b.rg;
        //float texOcclusion = data_b.b;
        float porosity = data_b.a;

        float roughL = roughness*roughness;

        albedo.rgb = RgbToLinear(albedo.rgb);

//        bool is_trans_fluid = iris_hasFluid(trans_blockId);
//
        bool isUnderWater = false;//ap.camera.fluid == 1
//            ? (depthTrans >= depthOpaque)
//            : (depthTrans < depthOpaque && is_trans_fluid);

        float wetness = float(isUnderWater);

        if (!isUnderWater) {
            float sky_wetness = GetSkyWetness(localPos, localTexNormal, lmCoord.y);

            wetness = max(wetness, sky_wetness);

            // only apply puddles out of water
            ApplyWetness_roughness(roughL, porosity, wetness);
            ApplyWetness_texNormal(localTexNormal, localGeoNormal, porosity, wetness);

            roughness = sqrt(roughL);
        }

        bool isWet = wetness > 0.2;

        float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

        #if LIGHTING_MODE == LIGHT_MODE_RT
            vec3 voxelPos = voxel_GetBufferPosition(localPos);
            vec3 voxelPos_in = voxelPos - 0.02*localGeoNormal;

            if (voxel_isInBounds(voxelPos_in)) {
//                #if defined EFFECT_TAA_ENABLED || defined ACCUM_ENABLED
//                    float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
//                #else
//                    float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
//                #endif

                ivec3 lightBinPos = ivec3(floor(voxelPos_in / LIGHT_BIN_SIZE));
                int lightBinIndex = GetLightBinIndex(lightBinPos);
                uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                vec3 voxelPos_out = voxelPos + 0.08*localGeoNormal;

                vec3 jitter = hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;
                //vec3 jitter = sample_blueNoise(gl_FragCoord.xy) * 0.5;
                jitter *= Lighting_PenumbraSize;

                #if RT_MAX_SAMPLE_COUNT > 0
                    uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
                    float bright_scale = binLightCount / float(RT_MAX_SAMPLE_COUNT);
                #else
                    uint maxSampleCount = binLightCount;
                    const float bright_scale = 1.0;
                #endif

                int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.time.frames)));

                for (int i = 0; i < maxSampleCount; i++) {
                    int i2 = (i + i_offset) % int(binLightCount);

                    uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2].voxelIndex;

                    vec3 light_voxelPos = GetLightVoxelPos(light_voxelIndex) + 0.5;
                    light_voxelPos += jitter;

                    vec3 light_LocalPos = voxel_getLocalPosition(light_voxelPos);

//                    uint blockId = imageLoad(imgVoxelBlock, ivec3(light_voxelPos)).r;

                    uint blockId = SampleVoxelBlock(light_voxelPos);

                    float lightRange = iris_getEmission(blockId);
                    vec3 lightColor = iris_getLightColor(blockId).rgb;
                    vec3 light_hsv = RgbToHsv(lightColor);
                    lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));
                    lightColor = RgbToLinear(lightColor);

//                    vec3 light_hsv = RgbToHsv(lightColor);
//                    lightColor = HsvToRgb(vec3(light_hsv.xy, 1.0));
//                    float lightIntensity = 1.0 - clamp(light_hsv.z, 0.0, 0.9);// mix(1000.0, 1.0, light_hsv.z);
//                    float lightIntensity2 = 0.0;//clamp(light_hsv.z, EPSILON, 1.0);//mix(1.0, 0.1, light_hsv.z);

                    vec3 lightVec = light_LocalPos - localPos;
                    float lightAtt = GetLightAttenuation(lightVec, lightRange);
                    //lightAtt *= light_hsv.z;

                    vec3 lightColorAtt = BLOCK_LUX * lightAtt * lightColor;

                    vec3 lightDir = normalize(lightVec);

                    vec3 H = normalize(lightDir + localViewDir);

                    float LoHm = max(dot(lightDir, H), 0.0);
                    float NoLm = max(dot(localTexNormal, lightDir), 0.0);
//                    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

                    if (NoLm == 0.0 || dot(localGeoNormal, lightDir) <= 0.0) continue;

                    float NoHm = max(dot(localTexNormal, H), 0.0);

                    //const bool isUnderWater = false;
                    float VoHm = max(dot(localViewDir, H), 0.0);
                    vec3 F = material_fresnel(albedo.rgb, f0_metal, roughL, VoHm, isWet);
                    vec3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
                    vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);

                    vec3 sampleDiffuse = NoLm * D * lightColorAtt;
                    vec3 sampleSpecular = NoLm * S * lightColorAtt;

                    vec3 traceStart = light_voxelPos;
                    vec3 traceEnd = voxelPos_out;
                    float traceRange = lightRange;
                    bool traceSelf = !iris_isFullBlock(blockId);

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
            }
        #endif

        //diffuseFinal = vec3(10.0,0.0,0.0);

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

//            vec3 sunTransmit, moonTransmit;
//            GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);

//            vec3 skyPos = getSkyPosition(vec3(0.0));
//            vec3 skyReflectColor = lmCoord.y * getValFromSkyLUT(texSkyView, skyPos, reflectLocalDir, Scene_LocalSunDir);
//
//            vec3 reflectSun = SUN_LUX * sun(reflectLocalDir, Scene_LocalSunDir) * sunTransmit * Scene_SunColor;
//            vec3 reflectMoon = MOON_LUX * moon(reflectLocalDir, -Scene_LocalSunDir) * moonTransmit * Scene_MoonColor;
//            skyReflectColor += shadow_sss.rgb * (reflectSun + reflectMoon);

            vec3 skyReflectColor = renderSky(localPos, reflectLocalDir, true);

//            vec3 reflectIrraidance = SampleSkyIrradiance(reflectLocalDir, lmCoord.y);
//            skyReflectColor = mix(skyReflectColor, reflectIrraidance, roughL);

            vec4 reflection = vec4(0.0);
            vec3 reflect_tint = vec3(1.0);

            vec2 reflect_lmcoord;
            vec4 reflect_normalData, reflect_specularData;
            vec3 reflect_voxelPos, reflect_geoNormal;
            vec4 reflect_hitColor;
            float reflect_lod = 0.0;

            if (roughL < 0.86) {
                #ifdef LIGHTING_REFLECT_TRIANGLE
                    // WSR: per-triangle

                    vec2 reflect_uv;
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

                        #if MATERIAL_FORMAT != MAT_NONE
                            reflect_normalData = textureLod(blockAtlasN, reflect_uv, reflect_lod);
                            reflect_specularData = textureLod(blockAtlasS, reflect_uv, reflect_lod);
                        #endif
                    }
                #else
                    // WSR: block-only

                    vec2 reflect_uv;
                    vec3 reflect_traceTint;
                    VoxelBlockFace blockFace;
                    vec3 traceStart = localPos + 0.1*localGeoNormal;
                    if (TraceReflection(traceStart, reflectLocalDir, reflect_traceTint, reflect_voxelPos, reflect_geoNormal, reflect_uv, blockFace)) {
                        vec3 reflect_localPos = voxel_getLocalPosition(reflect_voxelPos);
                        reflectDist = distance(traceStart, reflect_localPos);

                        if (blockFace.tex_id != -1u) {
                            reflect_tint = GetBlockFaceTint(blockFace.data);
                            reflect_lmcoord = GetBlockFaceLightMap(blockFace.data);

                            iris_TextureInfo tex = iris_getTexture(blockFace.tex_id);
                            reflect_uv = fma(reflect_uv, tex.maxCoord - tex.minCoord, tex.minCoord);

                            reflect_lod = textureQueryLod(blockAtlas, reflect_uv).y;

                            vec3 reflectColor = textureLod(blockAtlas, reflect_uv, reflect_lod).rgb;
                            reflection = vec4(reflectColor * reflect_traceTint, 1.0);

                            #if MATERIAL_FORMAT != MAT_NONE
                                reflect_normalData = textureLod(blockAtlasN, reflect_uv, reflect_lod);
                                reflect_specularData = textureLod(blockAtlasS, reflect_uv, reflect_lod);
                            #endif
                        }
                        else {
                            const vec3 reflectColor = _RgbToLinear(vec3(0.439, 0.404, 0.322));

                            reflect_tint = vec3(1.0);
                            reflect_lmcoord = vec2(0.0);
                            reflection = vec4(reflectColor, 1.0);
                        }
                    }
                #endif
            }

            if (reflection.a > 0.5) {
                reflection.rgb *= reflect_tint;
                reflection.rgb = RgbToLinear(reflection.rgb);

                //reflect_lmcoord = _pow3(reflect_lmcoord);

                #if MATERIAL_FORMAT != MAT_NONE
                    vec3 reflect_localTexNormal = mat_normal(reflect_normalData.xyz);
                    float reflect_roughness = mat_roughness(reflect_specularData.r);
                    float reflect_f0_metal = reflect_specularData.g;
                    float reflect_porosity = mat_porosity(reflect_specularData.b, reflect_roughness, reflect_f0_metal);
                    float reflect_emission = mat_emission(reflect_specularData);
                    float reflect_sss = mat_sss(reflect_specularData.b);
                #else
                    vec3 reflect_localTexNormal = localGeoNormal;
                    float reflect_roughness = 0.92;
                    float reflect_f0_metal = 0.0;
                    float reflect_porosity = 1.0;
                    float reflect_sss = 0.0;

                    float reflect_emission = iris_getEmission(blockId) / 15.0;
                #endif

                // TODO: get from TBN
                reflect_localTexNormal = reflect_geoNormal;

                float reflect_roughL = _pow2(reflect_roughness);

                vec3 reflect_localPos = voxel_getLocalPosition(reflect_voxelPos);

                float reflect_wetness = float(ap.camera.fluid == 1);

                float sky_wetness = smoothstep(0.9, 1.0, reflect_lmcoord.y) * ap.world.rain;
                reflect_wetness = max(reflect_wetness, sky_wetness);

                ApplyWetness_roughness(reflect_roughL, reflect_porosity, reflect_wetness);
                reflect_roughness = sqrt(reflect_roughL);

                #ifdef SHADOWS_ENABLED
                    float reflect_shadow = 1.0;

                    #ifdef SHADOW_VOXEL_TEST
                        vec3 currPos = reflect_voxelPos + 0.08 * reflect_geoNormal;
//                        vec3 sampleLocalPos = localPos + 0.08 * localGeoNormal;
//                        vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

                        vec3 stepSizes, nextDist, stepAxis;
                        dda_init(stepSizes, nextDist, currPos, Scene_LocalLightDir);

                        for (int i = 0; i < 4; i++) {
                            vec3 step = dda_step(stepAxis, nextDist, stepSizes, Scene_LocalLightDir);

                            ivec3 traceVoxelPos = ivec3(floor(currPos + 0.5*step));
                            if (!voxel_isInBounds(traceVoxelPos)) break;

                            uint blockId = SampleVoxelBlock(traceVoxelPos);
                            if (blockId != -1u) {
                                bool isFullBlock = iris_isFullBlock(blockId);
                                if (isFullBlock) {
                                    reflect_shadow = 0.0;
                                    break;
                                }
                            }

                            currPos += step;
                        }
                    #endif

                    int reflect_shadowCascade;
                    vec3 reflect_shadowViewPos = mul3(ap.celestial.view, reflect_localPos);
                    //reflect_shadowViewPos.z += 0.2;
                    const float shadowPadding = 2.0;
                    vec3 reflect_shadowPos = GetShadowSamplePos(reflect_shadowViewPos, shadowPadding, reflect_shadowCascade);

                    reflect_shadowPos.z -= GetShadowBias(reflect_shadowCascade);
                    reflect_shadow *= SampleShadow(reflect_shadowPos, reflect_shadowCascade);
                #else
                    float reflect_shadow = 1.0;
                #endif

                vec3 reflect_H = normalize(Scene_LocalLightDir + -reflectLocalDir);

                float reflect_NoLm = max(dot(reflect_localTexNormal, Scene_LocalLightDir), 0.0);
                float reflect_LoHm = max(dot(Scene_LocalLightDir, reflect_H), 0.0);
                float reflect_NoVm = max(dot(reflect_localTexNormal, -reflectLocalDir), 0.0);

                float NoL_sun = dot(reflect_localTexNormal, Scene_LocalSunDir);
                float NoL_moon = -NoL_sun;//dot(localTexNormal, -Scene_LocalSunDir);

                float skyLightF = smoothstep(0.0, 0.1, Scene_LocalLightDir.y);

                #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
                    skyLightF *= SampleCloudShadows(reflect_localPos);
                #endif

                vec3 reflect_sunTransmit, reflect_moonTransmit;
                GetSkyLightTransmission(reflect_localPos, reflect_sunTransmit, reflect_moonTransmit);
                vec3 sunLight = skyLightF * SUN_LUX * reflect_sunTransmit * Scene_SunColor;
                vec3 moonLight = skyLightF * MOON_LUX * reflect_moonTransmit * Scene_MoonColor;

                vec3 reflect_skyLight = sunLight * max(NoL_sun, 0.0)
                                      + moonLight * max(NoL_moon, 0.0);

                vec3 reflect_diffuse = reflect_skyLight * reflect_shadow;
                reflect_diffuse *= SampleLightDiffuse(reflect_NoVm, reflect_NoLm, reflect_LoHm, reflect_roughL);

                vec3 reflect_specular = vec3(0.0);

                vec3 reflect_skyIrradiance = SampleSkyIrradiance(reflect_localTexNormal, reflect_lmcoord.y);

                #ifdef LIGHTING_GI_ENABLED
                    vec3 reflect_wsgi_localPos = 0.5*reflect_geoNormal + reflect_localPos;

                    #ifdef LIGHTING_GI_SKYLIGHT
                        vec3 reflect_wsgi_bufferPos = wsgi_getBufferPosition(reflect_wsgi_localPos, WSGI_CASCADE_COUNT+WSGI_SCALE_BASE-1);

                        if (wsgi_isInBounds(reflect_wsgi_bufferPos))
                            reflect_skyIrradiance = vec3(0.0);
                    #endif

                    reflect_skyIrradiance += wsgi_sample(reflect_wsgi_localPos, reflect_localTexNormal);
                #endif

                reflect_diffuse += reflect_skyIrradiance;

                #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
                    if (!shadowPoint_isInBounds(reflect_localPos)) {
                        const float occlusion = 1.0;
                        reflect_diffuse += GetVanillaBlockLight(reflect_lmcoord.x, occlusion);
                    }
                    else {
                        sample_AllPointLights(reflect_diffuse, reflect_specular, reflect_localPos, reflect_geoNormal, reflect_geoNormal, reflection.rgb, reflect_f0_metal, reflect_roughL, reflect_sss);
                    }
                #elif LIGHTING_MODE == LIGHT_MODE_RT
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

                        uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2].voxelIndex;

                        vec3 light_voxelPos = GetLightVoxelPos(light_voxelIndex) + 0.5;
                        //light_voxelPos += jitter*0.125;

                        vec3 light_LocalPos = voxel_getLocalPosition(light_voxelPos);

                        //uint blockId = imageLoad(imgVoxelBlock, ivec3(light_voxelPos)).r;

                        uint blockId = SampleVoxelBlock(light_voxelPos);

                        float lightRange = iris_getEmission(blockId);
                        vec3 lightColor = iris_getLightColor(blockId).rgb;
                        vec3 light_hsv = RgbToHsv(lightColor);
                        lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));
                        lightColor = RgbToLinear(lightColor);

                        //float intensity = saturate(lightRange/15.0);
                        lightColor *= BLOCK_LUX;

                        vec3 lightVec = light_LocalPos - reflect_localPos;
                        float lightAtt = GetLightAttenuation(lightVec, lightRange);

                        vec3 lightDir = normalize(lightVec);

                        vec3 H = normalize(lightDir + -reflectLocalDir);

                        float LoHm = max(dot(lightDir, H), 0.0);
                        float NoLm = max(dot(reflect_localTexNormal, lightDir), 0.0);
                        //                    float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

                        if (NoLm == 0.0 || dot(reflect_geoNormal, lightDir) <= 0.0) continue;

                        float NoHm = max(dot(localTexNormal, H), 0.0);
                        float VoHm = max(dot(reflectLocalDir, H), 0.0);

                        const bool reflect_isUnderWater = false;
                        vec3 F = material_fresnel(albedo.rgb, f0_metal, reflect_roughL, VoHm, reflect_isUnderWater);
                        vec3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, reflect_roughL) * (1.0 - F);
                        vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, reflect_roughL);

                        vec3 lightFinal = NoLm * lightAtt * lightColor;
                        vec3 sampleDiffuse = D * lightFinal;
                        vec3 sampleSpecular = S * lightFinal;

                        vec3 traceStart = light_voxelPos;
                        vec3 traceEnd = voxelPos_out;
                        float traceRange = lightRange;
                        bool traceSelf = !iris_isFullBlock(blockId);

                        vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

                        reflect_diffuse += sampleDiffuse * shadow_color * bright_scale;
                        //reflect_specular += sampleSpecular * shadow_color * bright_scale;
                    }
                #elif LIGHTING_MODE == LIGHT_MODE_VANILLA
                    const float occlusion = 1.0;
                    reflect_diffuse += GetVanillaBlockLight(reflect_lmcoord.x, occlusion);
                #endif

                #ifdef FLOODFILL_ENABLED
                    vec3 voxelSamplePos = fma(reflect_geoNormal, vec3(0.5), reflect_voxelPos);
                    vec3 voxelLight = floodfill_sample(voxelSamplePos);

                    // TODO: move cloud shadows to RSM sampling!!!
                    reflect_diffuse += voxelLight;// * cloudShadowF;// * SampleLightDiffuse(NoVm, 1.0, 1.0, roughL);
                #endif

                reflect_diffuse += 0.0016;

                float reflect_metalness = mat_metalness(reflect_f0_metal);
                reflect_diffuse *= 1.0 - reflect_metalness * (1.0 - reflect_roughL);

                #if MATERIAL_EMISSION_POWER != 1
                    reflect_diffuse += pow(reflect_emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
                #else
                    reflect_diffuse += reflect_emission * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
                #endif

                #ifdef LIGHTING_GI_ENABLED
                    // TODO: get inner reflection vector and use for SH lookup

                    //vec3 wsgi_bufferPos = reflect_voxelPos + (VoxelBufferCenter - WSGI_BufferCenter);
                    vec3 wsgi_localPos = 0.25*reflect_geoNormal + reflect_localPos;

                    //if (wsgi_isInBounds(wsgi_bufferPos)) {
                        vec3 reflect_reflectDir = reflect(reflectLocalDir, reflect_localTexNormal);

                        vec3 reflect_irradiance = wsgi_sample(wsgi_localPos, reflect_reflectDir);
                        reflect_specular += reflect_irradiance; // * S * reflect_tint;
                    //}
                #endif

                float reflect_NoHm = max(dot(reflect_localTexNormal, reflect_H), 0.0);
                float reflect_VoHm = max(dot(-reflectLocalDir, reflect_H), 0.0);

                const bool reflect_isWet = false;
                vec3 reflect_F = material_fresnel(reflection.rgb, reflect_f0_metal, reflect_roughL, reflect_VoHm, reflect_isWet);
                vec3 reflect_sunS = SampleLightSpecular(reflect_NoLm, reflect_NoHm, reflect_NoVm, reflect_F, reflect_roughL);

                // TODO: move reflect_diffuse here?
                reflect_diffuse *= 1.0 - reflect_F;
                reflect_specular += reflect_skyLight * reflect_shadow * reflect_sunS;// * vec3(1,0,0);

                float smoothness = 1.0 - reflect_roughness;
                reflect_specular *= GetMetalTint(reflection.rgb, reflect_f0_metal) * _pow2(smoothness);

                #ifdef DEBUG_WHITE_WORLD
                    reflection.rgb = WhiteWorld_Value;
                #endif

                ApplyWetness_albedo(reflection.rgb, reflect_porosity, reflect_wetness);

                skyReflectColor = fma(reflection.rgb, reflect_diffuse, reflect_specular);
                //skyReflectColor = mix(reflection.rgb * reflect_diffuse, reflect_specular, reflect_view_F);
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

                reflectDist = ap.camera.far;
                if (reflection.a > EPSILON) {
                    vec3 reflected_viewPos = unproject(ap.camera.projectionInv, reflection.xyz * 2.0 - 1.0);
                    reflectDist = length(reflected_viewPos);
                }

                float maxLod = max(log2(minOf(ap.game.screenSize)) - 2.0, 0.0);
                float screenDist = length((reflection.xy - uv) * (ap.game.screenSize/2.0));
                float roughMip = min(roughness * min(log2(screenDist + 1.0), 6.0), maxLod);
                vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

                skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
            }

            //const bool isWet = false;
            //float smoothness = 1.0 - roughness;
            //vec3 reflectTint = GetMetalTint(albedo.rgb, f0_metal);
            //vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
            specularFinal += skyReflectColor;// * smoothness;// * (1.0 - roughL);// * reflectTint * _pow2(smoothness);
        #endif
    }

    outDiffuseRT = vec4(diffuseFinal * BufferLumScaleInv, 1.0);
    outSpecularRT = vec4(specularFinal * BufferLumScaleInv, reflectDist);
}
