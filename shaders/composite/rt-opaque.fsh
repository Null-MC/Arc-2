#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outDiffuseRT;
layout(location = 1) out vec4 outSpecularRT;

//#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR && !defined(LIGHTING_REFLECT_TRIANGLE)
//    layout(r32ui) uniform readonly uimage3D imgVoxelBlock;
//#endif

uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;
uniform sampler2D texDeferredOpaque_TexNormal;

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

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/buffers/triangle-list.glsl"
#else
    #include "/lib/buffers/voxel-block.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"

#include "/lib/material/material_fresnel.glsl"

#include "/lib/voxel/voxel_common.glsl"

#ifdef VOXEL_TRI_ENABLED
    #include "/lib/voxel/triangle-test.glsl"
    #include "/lib/voxel/triangle-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT
    #include "/lib/voxel/light-list.glsl"
    #include "/lib/voxel/dda-trace.glsl"
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    #include "/lib/buffers/scene.glsl"

    #ifndef LIGHTING_REFLECT_TRIANGLE
//        #include "/lib/buffers/voxel-block.glsl"
    #endif

    #include "/lib/erp.glsl"
    #include "/lib/material/material.glsl"

    #include "/lib/sky/common.glsl"
    #include "/lib/sky/view.glsl"
    #include "/lib/sky/sun.glsl"
    #include "/lib/sky/transmittance.glsl"

    #include "/lib/utility/blackbody.glsl"

    #ifdef LIGHTING_REFLECT_TRIANGLE
        #include "/lib/effects/wsr-triangle.glsl"
    #else
        #include "/lib/effects/wsr-block.glsl"
    #endif

    #ifdef SHADOWS_ENABLED
        #include "/lib/shadow/csm.glsl"
        #include "/lib/shadow/sample.glsl"
    #endif

    #include "/lib/depth.glsl"
    #include "/lib/effects/ssr.glsl"

    #include "/lib/composite-shared.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(fma(uv, ap.game.screenSize, vec2(0.5)));
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 diffuseFinal = vec3(0.0);
    vec3 specularFinal = vec3(0.0);

    if (depth < 1.0) {
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        // vec2 pixelSize = 1.0 / ap.game.screenSize;

        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);

        // float viewDist = length(viewPos);

        vec3 normalData = texelFetch(texDeferredOpaque_TexNormal, iuv, 0).xyz;
        vec3 localTexNormal = normalize(normalData * 2.0 - 1.0);

        // vec3 viewNormal = mat3(ap.camera.view) * localNormal;

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(data_r * 2.0 - 1.0);

        vec3 voxelPos = GetVoxelPosition(localPos);
        vec3 voxelPos_in = voxelPos - 0.02*localGeoNormal;

        if (IsInVoxelBounds(voxelPos_in)) {
            #if defined EFFECT_TAA_ENABLED || defined ACCUM_ENABLED
                float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
            #else
                float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
            #endif

            vec4 albedo = texelFetch(texDeferredOpaque_Color, iuv, 0);
            albedo.rgb = RgbToLinear(albedo.rgb);

            vec4 data_g = unpackUnorm4x8(data.g);
            float roughness = data_g.x;
             float f0_metal = data_g.y;
            // float emission = data_g.z;
            // float sss = data_g.w;

            #if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
                vec4 data_b = unpackUnorm4x8(data.b);
                vec2 lmCoord = data_b.rg;
//                float texOcclusion = data_b.b;
            #endif

            float roughL = roughness*roughness;

            vec3 localViewDir = normalize(-localPos);

            float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

            #if LIGHTING_MODE == LIGHT_MODE_RT
                ivec3 lightBinPos = ivec3(floor(voxelPos_in / LIGHT_BIN_SIZE));
                int lightBinIndex = GetLightBinIndex(lightBinPos);
                uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                vec3 voxelPos_out = voxelPos + 0.02*localGeoNormal;

                vec3 jitter = hash33(vec3(gl_FragCoord.xy, ap.frame.counter)) - 0.5;

                #if RT_MAX_SAMPLE_COUNT > 0
                    uint maxSampleCount = min(binLightCount, RT_MAX_SAMPLE_COUNT);
                    float bright_scale = ceil(binLightCount / float(RT_MAX_SAMPLE_COUNT));
                #else
                    uint maxSampleCount = binLightCount;
                    const float bright_scale = 1.0;
                #endif

                int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.frame.counter)));

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
                    bool traceSelf = false;

                    #ifdef RT_TRI_ENABLED
                        vec3 traceRay = traceEnd - traceStart;
                        vec3 direction = normalize(traceRay);

                        vec3 stepDir = sign(direction);
                        // vec3 stepSizes = 1.0 / abs(direction);
                        vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(traceStart)) / direction;

                        float closestDist = minOf(nextDist);
                        traceStart += direction * closestDist;

                        // vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

                        // nextDist -= closestDist;
                        // nextDist += stepSizes * stepAxis;



                        // ivec3 triangle_offset = ivec3(voxelPos) % TRIANGLE_BIN_SIZE;
                        // traceStart -= triangle_offset;
                        // traceEnd -= triangle_offset;

                        traceStart /= TRIANGLE_BIN_SIZE;
                        traceEnd /= TRIANGLE_BIN_SIZE;
                        traceSelf = true;
                    #endif

                    vec3 shadow_color = TraceDDA(traceStart, traceEnd, lightRange, traceSelf);

                    diffuseFinal += sampleDiffuse * shadow_color * bright_scale;
                    specularFinal += sampleSpecular * shadow_color * bright_scale;
                }
            #endif

            #if LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
                // reflections
                vec3 reflectLocalDir = reflect(-localViewDir, localTexNormal);

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

                        vec3 reflect_hitCoord;
                        Triangle reflect_hitTriangle;
                        if (TraceReflection(localPos + 0.1*localGeoNormal, reflectLocalDir, reflect_voxelPos, reflect_uv, reflect_hitCoord, reflect_hitColor, reflect_hitTriangle)) {
                            reflection = reflect_hitColor;

                            reflect_tint = unpackUnorm4x8(reflect_hitTriangle.tint).rgb;

                            vec2 lmcoords[3];
                            GetTriangleLightMapCoord(reflect_hitTriangle.lmcoord, lmcoords[0], lmcoords[1], lmcoords[2]);
                            reflect_lmcoord = lmcoords[0] * reflect_hitCoord.x;
                            reflect_lmcoord = fma(lmcoords[1], vec2(reflect_hitCoord.y), reflect_lmcoord);
                            reflect_lmcoord = fma(lmcoords[2], vec2(reflect_hitCoord.z), reflect_lmcoord);

                            vec3 tri_pos_0 = GetTriangleVertexPos(reflect_hitTriangle.pos[0]);
                            vec3 tri_pos_1 = GetTriangleVertexPos(reflect_hitTriangle.pos[1]);
                            vec3 tri_pos_2 = GetTriangleVertexPos(reflect_hitTriangle.pos[2]);

                            vec3 e1 = normalize(tri_pos_1 - tri_pos_0);
                            vec3 e2 = normalize(tri_pos_2 - tri_pos_0);
                            reflect_geoNormal = normalize(cross(e1, e2));
                        }
                    #else
                        // WSR: block-only

                        VoxelBlockFace blockFace;
                        if (TraceReflection(localPos + 0.1*localGeoNormal, reflectLocalDir, reflect_voxelPos, reflect_geoNormal, blockFace)) {
                            GetBlockFaceLightMap(blockFace.lmcoord, reflect_lmcoord);

                            reflect_tint = unpackUnorm4x8(blockFace.tint).rgb;

                            iris_TextureInfo tex = iris_getTexture(blockFace.tex_id);
                            reflect_uv = 0.5 * (tex.minCoord + tex.maxCoord);

                            vec3 reflectColor = textureLod(blockAtlas, reflect_uv, 4).rgb;
                            reflection = vec4(reflectColor, 1.0);
                        }
                    #endif
                }

                if (reflection.a > 0.0) {
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
                        vec3 reflect_shadowPos = GetShadowSamplePos(reflect_shadowViewPos, 0.0, reflect_shadowCascade);
                        float reflect_shadow = SampleShadow(reflect_shadowPos, reflect_shadowCascade);
                    #else
                        float reflect_shadow = 1.0;
                    #endif

                    vec3 H = normalize(Scene_LocalLightDir + reflectLocalDir);

                    float reflect_NoLm = max(dot(reflect_localTexNormal, Scene_LocalLightDir), 0.0);
                    float reflect_LoHm = max(dot(Scene_LocalLightDir, H), 0.0);
                    float reflect_NoVm = max(dot(reflect_localTexNormal, reflectLocalDir), 0.0);

                    vec3 skyLight = SUN_BRIGHTNESS * sunTransmit + MOON_BRIGHTNESS * moonTransmit;
                    vec3 reflect_diffuse = reflect_NoLm * skyLight * reflect_shadow;
                    reflect_diffuse *= SampleLightDiffuse(reflect_NoVm, reflect_NoLm, reflect_LoHm, reflect_roughL);

                    vec2 skyIrradianceCoord = DirectionToUV(reflect_localTexNormal);
                    vec3 reflect_skyIrradiance = textureLod(texSkyIrradiance, skyIrradianceCoord, 0).rgb;
                    reflect_diffuse += (SKY_AMBIENT * SKY_BRIGHTNESS * reflect_lmcoord.y) * reflect_skyIrradiance;
                    reflect_diffuse += blackbody(BLOCKLIGHT_TEMP) * (BLOCKLIGHT_BRIGHTNESS * reflect_lmcoord.x);
                    reflect_diffuse += 0.0016;

                    float reflect_metalness = mat_metalness(reflect_f0_metal);
                    reflect_diffuse *= 1.0 - reflect_metalness * (1.0 - reflect_roughL);

                    #if MATERIAL_EMISSION_POWER != 1
                        reflect_diffuse += pow(reflect_emission, MATERIAL_EMISSION_POWER) * EMISSION_BRIGHTNESS;
                    #else
                        reflect_diffuse += reflect_emission * EMISSION_BRIGHTNESS;
                    #endif

                    //                reflection.rgb = max(reflect_localTexNormal, 0.0);

                    vec3 reflectFinal = reflection.rgb * reflect_diffuse;// + reflect_specular;

                    skyReflectColor = mix(skyReflectColor, reflectFinal, reflection.a);
                }

                if (reflection.a == 0.0) {
                    float viewDist = length(localPos);
                    vec3 reflectViewDir = mat3(ap.camera.view) * reflectLocalDir;
                    vec3 reflectViewPos = viewPos + 0.5*viewDist*reflectViewDir;
                    vec3 reflectClipPos = unproject(ap.camera.projection, reflectViewPos) * 0.5 + 0.5;

                    vec3 clipPos = ndcPos * 0.5 + 0.5;
                    vec3 reflectRay = normalize(reflectClipPos - clipPos);
                    reflection = GetReflectionPosition(solidDepthTex, clipPos, reflectRay);

                    float maxLod = max(log2(minOf(ap.game.screenSize)) - 2.0, 0.0);
                    float screenDist = length((reflection.xy - uv) * (ap.game.screenSize/2.0));
                    float roughMip = min(roughness * min(log2(screenDist + 1.0), 6.0), maxLod);
                    vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

                    skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
                }

                const bool isWet = false;
                vec3 reflectTint = GetMetalTint(albedo.rgb, f0_metal);
                vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
                specularFinal += view_F * skyReflectColor * reflectTint * (1.0 - roughness);
//                specularFinal += skyReflectColor;
            #endif
        }
    }

    outDiffuseRT = vec4(diffuseFinal, 1.0);
    outSpecularRT = vec4(specularFinal, 1.0);
}
