#version 430 core
#extension GL_ARB_derivative_control: enable

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;

uniform sampler2D texDeferredOpaque_Color;
uniform sampler2D texDeferredOpaque_TexNormal;
uniform usampler2D texDeferredOpaque_Data;
uniform usampler2D texDeferredTrans_Data;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyIrradiance;

uniform sampler2D texParticleOpaque;

uniform sampler3D texFogNoise;
uniform sampler2D texBlueNoise;

#if defined(SHADOWS_ENABLED) || defined(SHADOWS_SS_FALLBACK)
    uniform sampler2D TEX_SHADOW;
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    uniform sampler2D texFinalPrevious;
#endif

#if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
    #ifdef WORLD_END
        uniform sampler2D texEndSun;
        uniform sampler2D texEarth;
        uniform sampler2D texEarthSpecular;
    #elif defined(WORLD_SKY_ENABLED)
        uniform sampler2D texMoon;
    #endif
#endif

#ifdef EFFECT_SSAO_ENABLED
    uniform sampler2D TEX_SSAO;
#endif

#ifdef EFFECT_VL_ENABLED
    uniform sampler2D texScatterVL;
    uniform sampler2D texTransmitVL;
#endif

#ifdef ACCUM_ENABLED
    uniform sampler2D texAccumDiffuse_opaque;
    uniform sampler2D texAccumDiffuse_opaque_alt;
    uniform sampler2D texAccumSpecular_opaque;
    uniform sampler2D texAccumSpecular_opaque_alt;

    #ifdef EFFECT_SSAO_ENABLED
        uniform sampler2D texAccumOcclusion_opaque;
        uniform sampler2D texAccumOcclusion_opaque_alt;
    #endif
#elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
    uniform sampler2D texDiffuseRT;
    uniform sampler2D texSpecularRT;
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

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#ifdef HANDLIGHT_TRACE
    #include "/lib/buffers/voxel-block.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #include "/lib/buffers/light-list.glsl"
#endif

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/buffers/wsgi.glsl"
#endif

#include "/lib/sampling/erp.glsl"
#include "/lib/sampling/depth.glsl"
#include "/lib/hg.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/noise/blue.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"
#include "/lib/utility/dfd-normal.glsl"
#include "/lib/utility/hsv.glsl"
#include "/lib/utility/tbn.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"
#include "/lib/light/volumetric.glsl"
#include "/lib/light/brdf.glsl"
#include "/lib/light/meta.glsl"

#include "/lib/material/material.glsl"
#include "/lib/material/material_fresnel.glsl"
#include "/lib/material/wetness.glsl"

#include "/lib/lightmap/sample.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/irradiance.glsl"
#include "/lib/sky/transmittance.glsl"

#if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
    #ifdef WORLD_END
        #include "/lib/sky/sky-end.glsl"
    #elif defined(WORLD_SKY_ENABLED)
        #include "/lib/sky/sky-overworld.glsl"
    #endif

    #include "/lib/sky/render.glsl"
#endif

#if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
    #include "/lib/effects/ssr.glsl"
#endif

#include "/lib/voxel/voxel-common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #include "/lib/voxel/light-list.glsl"
#endif

#ifdef HANDLIGHT_TRACE
    #include "/lib/voxel/dda.glsl"
    #include "/lib/voxel/voxel-sample.glsl"
    #include "/lib/voxel/light-trace.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #include "/lib/shadow-point/common.glsl"
    #include "/lib/shadow-point/sample-common.glsl"
    #include "/lib/shadow-point/sample-geo.glsl"
#endif

#ifdef FLOODFILL_ENABLED
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
    #include "/lib/sky/clouds.glsl"
    #include "/lib/shadow/clouds.glsl"
#endif

#ifdef LIGHTING_GI_ENABLED
    #include "/lib/voxel/wsgi-common.glsl"
    #include "/lib/voxel/wsgi-sample.glsl"
#endif

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif

#include "/lib/composite-shared.glsl"


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depthTrans = texelFetch(mainDepthTex, iuv, 0).r;
    vec4 albedo = texelFetch(texDeferredOpaque_Color, iuv, 0);
    vec4 colorFinal = vec4(0.0);

    float depthOpaque = 1.0;
    if (albedo.a > EPSILON) {
        depthOpaque = texelFetch(solidDepthTex, iuv, 0).r;
    }

    vec3 ndcPos = fma(vec3(uv, depthOpaque), vec3(2.0), vec3(-1.0));

    #ifdef EFFECT_TAA_ENABLED
        unjitter(ndcPos);
    #endif

    uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
    uint blockId = data.a;

    if (blockId == BLOCK_HAND) {
        ndcPos.z /= MC_HAND_DEPTH;
    }

    vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

    vec3 localViewDir = normalize(localPos);

    if (albedo.a > EPSILON) {
        vec3 texNormalData = texelFetch(texDeferredOpaque_TexNormal, iuv, 0).rgb;
//        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        uint trans_blockId = texelFetch(texDeferredTrans_Data, iuv, 0).a;
//        uint blockId = data.a;

        #ifdef ACCUM_ENABLED
            bool altFrame = (ap.time.frames % 2) == 1;
        #endif

        albedo.rgb = RgbToLinear(albedo.rgb);

        vec3 data_r = unpackUnorm4x8(data.r).rgb;
        vec3 localGeoNormal = normalize(fma(data_r, vec3(2.0), vec3(-1.0)));

        vec3 localTexNormal = vec3(0.5, 0.5, 1.0);
        bool hasTexNormal = any(greaterThan(texNormalData.xy, vec2(0.0)));
        if (hasTexNormal) localTexNormal = normalize(fma(texNormalData, vec3(2.0), vec3(-1.0)));

        vec4 data_g = unpackUnorm4x8(data.g);
        float roughness = data_g.x;
        float f0_metal = data_g.y;
        float emission = data_g.z;
        float sss = data_g.w;

        vec4 data_b = unpackUnorm4x8(data.b);
        vec2 lmCoord = data_b.rg;
        float texOcclusion = data_b.b;
        float porosity = data_b.a;

        bool is_trans_fluid = iris_hasFluid(trans_blockId);

        bool isUnderWater = ap.camera.fluid == 1
            ? (depthTrans >= depthOpaque)
            : (depthTrans < depthOpaque && is_trans_fluid);

        float wetness = float(isUnderWater);

        if (!isUnderWater) {
            float sky_wetness = GetSkyWetness(localPos, localTexNormal, lmCoord.y);

            wetness = max(wetness, sky_wetness);
        }

        bool isWet = wetness > 0.2;

        //lmCoord = _pow3(lmCoord);

        float roughL = _pow2(roughness);

        if (!isUnderWater && wetness > 0.0) {
            // only apply puddles out of water

            ApplyWetness_roughness(roughL, porosity, wetness);
            ApplyWetness_texNormal(localTexNormal, localGeoNormal, porosity, wetness);

            roughness = sqrt(roughL);
        }

        // Lighting
        float NoVm = max(dot(localTexNormal, -localViewDir), 0.0);
        #ifdef WORLD_SKY_ENABLED
            bool isDay = Scene_LocalSunDir.y > 0.0;
            float skyLightDist = isDay ? skyLight_AreaDist : moon_distanceKm;
            float skyLightSize = isDay ? skyLight_AreaSize : moon_radiusKm;
            vec3 skyLightAreaDir = GetAreaLightDir(localTexNormal, localViewDir, Scene_LocalLightDir, skyLightDist, skyLightSize);

            vec3 H = normalize(skyLightAreaDir + -localViewDir);

            float NoLm = max(dot(localTexNormal, skyLightAreaDir), 0.0);
            float LoHm = max(dot(skyLightAreaDir, H), 0.0);

            vec4 shadow_sss = vec4(lmCoord.y);
            #if defined(SHADOWS_ENABLED) || defined(SHADOWS_SS_FALLBACK)
                shadow_sss = textureLod(TEX_SHADOW, uv, 0);
            #endif
        #endif

        float occlusion = texOcclusion;

        #ifdef EFFECT_SSAO_ENABLED
            #ifdef ACCUM_ENABLED
                float ssao_occlusion;
                if (altFrame) ssao_occlusion = textureLod(texAccumOcclusion_opaque_alt, uv, 0).r;
                else ssao_occlusion = textureLod(texAccumOcclusion_opaque, uv, 0).r;
            #else
                float ssao_occlusion = textureLod(TEX_SSAO, uv, 0).r;
            #endif

            occlusion *= ssao_occlusion;
        #endif

        #ifdef WORLD_SKY_ENABLED
            #ifdef WORLD_END
                float skyLightF = 1.0;
                vec3 sunTransmit = vec3(1.0);
                vec3 moonTransmit = vec3(1.0);
            #elif defined(WORLD_SKY_ENABLED)
                vec3 sunTransmit, moonTransmit;
                GetSkyLightTransmission(localPos, sunTransmit, moonTransmit);

                float skyLightF = smoothstep(0.0, 0.1, Scene_LocalLightDir.y);

                #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
                    skyLightF *= SampleCloudShadows(localPos);
                #endif
            #endif

            vec3 sunLight = skyLightF * SUN_LUX * sunTransmit * Scene_SunColor;
            vec3 moonLight = skyLightF * MOON_LUX * moonTransmit * Scene_MoonColor;

            float NoL_sun = dot(localTexNormal, Scene_LocalSunDir);
            float NoL_moon = -NoL_sun;
        #endif

        #ifdef VL_SELF_SHADOW
            #ifdef EFFECT_TAA_ENABLED
                float shadow_dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
            #else
                float shadow_dither = InterleavedGradientNoise(gl_FragCoord.xy);
            #endif

            float shadowStepDist = 1.0;
            float shadowDensity = 0.0;
            for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
                vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + localPos;

                float shadowSampleDensity = VL_WaterDensity;
                if (ap.camera.fluid != 1) {
                    shadowSampleDensity = GetSkyDensity(fogShadow_localPos);

                    #ifdef SKY_FOG_NOISE
                        shadowSampleDensity += SampleFogNoise(fogShadow_localPos);
                    #endif
                }

                shadowDensity += shadowSampleDensity * shadowStepDist;// * (1.0 - max(1.0 - ii, 0.0));
                shadowStepDist *= 2.0;
            }

            if (shadowDensity > 0.0) {
                float transmittance = exp(-VL_ShadowTransmit * shadowDensity);
                sunLight *= transmittance;
                moonLight *= transmittance;
            }
        #endif

        vec3 diffuse = vec3(0.0);
        vec3 specular = vec3(0.0);

        #ifdef WORLD_SKY_ENABLED
            vec3 shadow = shadow_sss.rgb * step(0.0, dot(localGeoNormal, Scene_LocalLightDir));

            float NoHm = max(dot(localTexNormal, H), 0.0);
            float VoHm = max(dot(-localViewDir, H), 0.0);

            float sss_sun_NoLm = max((NoL_sun + sss) / (1.0 + sss), 0.0);
            vec3 sss_shadow = mix(shadow, vec3(shadow_sss.w), sss);

            vec3 F = material_fresnel(albedo.rgb, f0_metal, roughL, VoHm, isWet);
            vec3 D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL) * (1.0 - F);
            vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, F, roughL);// * roughL;

            diffuse += D * (sunLight * sss_sun_NoLm + moonLight * max(NoL_moon, 0.0)) * sss_shadow;
            specular += S * (sunLight * max(NoL_sun, 0.0) + moonLight * max(NoL_moon, 0.0)) * shadow;
        #endif

        diffuse += 0.0016 * occlusion;

        #if defined(WORLD_SKY_ENABLED) && !defined(WORLD_END)
            vec3 skyIrradiance = SampleSkyIrradiance(localTexNormal, lmCoord.y);
            //skyIrradiance *= mix(2.0, 1.0, skyLightF);

            #ifdef LIGHTING_GI_ENABLED
                vec3 wsgi_localPos = 0.5*localGeoNormal + localPos;

                #ifdef LIGHTING_GI_SKYLIGHT
                    vec3 wsgi_bufferPos = wsgi_getBufferPosition(wsgi_localPos, WSGI_CASCADE_COUNT+WSGI_SCALE_BASE-1);

                    if (wsgi_isInBounds(wsgi_bufferPos))
                        skyIrradiance = vec3(0.0);
                #endif

                skyIrradiance += wsgi_sample(wsgi_localPos, localTexNormal);
            #endif

            diffuse += skyIrradiance * occlusion;
        #endif

        vec3 blockLighting = GetVanillaBlockLight(lmCoord.x, occlusion);
        vec3 voxelPos = voxel_GetBufferPosition(localPos);

        #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
            if (shadowPoint_isInBounds(localPos)) {
                blockLighting = vec3(0.0);
            }
        #elif LIGHTING_MODE == LIGHT_MODE_RT
            // TODO: replace check with light-list bounds!
            if (voxel_isInBounds(voxelPos)) {
                blockLighting = vec3(0.0);
            }
        #endif

        #ifdef FLOODFILL_ENABLED
            vec3 voxelSamplePos = 0.5*localTexNormal - 0.25*localGeoNormal + voxelPos;

            if (floodfill_isInBounds(voxelSamplePos)) {
                vec3 floodfill_light = floodfill_sample(voxelSamplePos);
//                #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
//                    vec3 floodfill_light = floodfill_sample(voxelSamplePos, 5.0);
//                #else
//                    vec3 floodfill_light = floodfill_sample(voxelSamplePos);
//                #endif

                #if LIGHTING_MODE == LIGHT_MODE_LPV
                    float floodfill_FadeF = floodfill_getFade(voxelPos);
                    blockLighting = mix(blockLighting, floodfill_light, floodfill_FadeF);
                #else
                    blockLighting += floodfill_light * (1.0/15.0);
                #endif
            }
        #endif

        diffuse += blockLighting;

        #ifdef ACCUM_ENABLED
            vec3 accumDiffuse;
            if (altFrame) accumDiffuse = textureLod(texAccumDiffuse_opaque_alt, uv, 0).rgb;
            else accumDiffuse = textureLod(texAccumDiffuse_opaque, uv, 0).rgb;

            diffuse += accumDiffuse * BufferLumScale;
        #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
            diffuse += textureLod(texDiffuseRT, uv, 0).rgb * BufferLumScale;
        #endif

//        vec3 view_F = vec3(0.0);
//        vec3 specular = vec3(0.0);

        #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
            sample_AllPointLights(diffuse, specular, localPos, localGeoNormal, localTexNormal, albedo.rgb, f0_metal, roughL, sss);
        #endif

        if (hasTexNormal) {
            // reflections
            #if LIGHTING_REFLECT_MODE != REFLECT_MODE_WSR
                vec3 viewDir = normalize(viewPos);
                vec3 viewNormal = mat3(ap.camera.view) * localTexNormal;
                vec3 reflectViewDir = reflect(viewDir, viewNormal);
                vec3 reflectLocalDir = mat3(ap.camera.viewInv) * reflectViewDir;

                #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                    randomize_reflection(reflectLocalDir, localTexNormal, roughness);
                #endif

                vec3 skyReflectColor = renderSky(localPos, reflectLocalDir, true);

                vec3 reflectIrraidance = SampleSkyIrradiance(reflectLocalDir, lmCoord.y);
                skyReflectColor = mix(skyReflectColor, reflectIrraidance, roughL);
            #else
                vec3 skyReflectColor = vec3(0.0);
            #endif

//            if (!hasTexNormal) NoVm = 1.0;

//            float NoHm = max(dot(localTexNormal, H), 0.0);
//            float VoHm = max(dot(-localViewDir, H), 0.0);

//            view_F = material_fresnel(albedo.rgb, f0_metal, roughL, VoHm, isWet);
//            vec3 S = SampleLightSpecular(NoLm, NoHm, NoVm, view_F, roughL);

            //specular += S * skyLightFinal * shadow_sss.rgb;


            vec4 reflection = vec4(0.0);

            #if LIGHTING_REFLECT_MODE == REFLECT_MODE_SSR
                float viewDist = length(viewPos);
                vec3 reflectLocalPos = fma(reflectLocalDir, vec3(0.5*viewDist), localPos);

                vec3 reflectViewStart = mul3(ap.temporal.view, localPos);
                vec3 reflectViewEnd = mul3(ap.temporal.view, reflectLocalPos);

                vec3 reflectNdcStart = unproject(ap.temporal.projection, reflectViewStart);
                vec3 reflectNdcEnd = unproject(ap.temporal.projection, reflectViewEnd);

                vec3 reflectRay = normalize(reflectNdcEnd - reflectNdcStart);

                vec3 clipPos = fma(reflectNdcStart, vec3(0.5), vec3(0.5));
                reflection = GetReflectionPosition(mainDepthTex, clipPos, reflectRay);

                #ifdef MATERIAL_ROUGH_REFLECT_NOISE
                    float maxLod = max(log2(minOf(ap.game.screenSize)) - 2.0, 0.0);
                    float screenDist = length((reflection.xy - uv) * ap.game.screenSize);
                    float roughMip = min(roughness * min(log2(screenDist + 1.0), 6.0), maxLod);
                #else
                    const float roughMip = 0.0;
                #endif

                vec3 reflectColor = GetRelectColor(texFinalPrevious, reflection.xy, reflection.a, roughMip);

                skyReflectColor = mix(skyReflectColor, reflectColor, reflection.a);
            #endif

            vec3 view_F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isWet);
            specular += view_F * skyReflectColor * (1.0 - roughL);

            #ifdef ACCUM_ENABLED
                vec3 accumSpecular;
                if (altFrame) accumSpecular = textureLod(texAccumSpecular_opaque_alt, uv, 0).rgb;
                else accumSpecular = textureLod(texAccumSpecular_opaque, uv, 0).rgb;

                specular += view_F * accumSpecular * BufferLumScale;
            #elif LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_REFLECT_MODE == REFLECT_MODE_WSR
                specular += view_F * textureLod(texSpecularRT, uv, 0).rgb * BufferLumScale;
            #endif
        }

        vec3 handSampleLocalPos = localGeoNormal*0.02 + localPos;

        if (ap.game.mainHand != 0u) {
            vec3 lightLocalPos = GetHandLightPos(0.2);
            GetHandLight(diffuse, specular, ap.game.mainHand, lightLocalPos, handSampleLocalPos, -localViewDir, localTexNormal, localGeoNormal, albedo.rgb, f0_metal, roughL);
        }

        if (ap.game.offHand != 0u) {
            vec3 lightLocalPos = GetHandLightPos(-0.2);
            GetHandLight(diffuse, specular, ap.game.offHand, lightLocalPos, handSampleLocalPos, -localViewDir, localTexNormal, localGeoNormal, albedo.rgb, f0_metal, roughL);
        }

        float metalness = mat_metalness(f0_metal);
        diffuse *= 1.0 - metalness * (1.0 - roughL);

        #if MATERIAL_EMISSION_POWER != 1
            diffuse += pow(emission, MATERIAL_EMISSION_POWER) * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
        #else
            diffuse += emission * Material_EmissionBrightness * BLOCKLIGHT_LUMINANCE;
        #endif

        //float smoothness = 1.0 - roughness;
        specular *= GetMetalTint(albedo.rgb, f0_metal);// * smoothness;

        //        if (!hasTexNormal) albedo.rgb = vec3(1.0,0.0,0.0);

        #ifdef DEBUG_WHITE_WORLD
            albedo.rgb = WhiteWorld_Value;
        #endif

        #if DEBUG_VIEW == DEBUG_VIEW_IRRADIANCE && defined(LIGHTING_GI_ENABLED)
            albedo.rgb = vec3(1.0);

            {
                int wsgi_cascade = -1;
                ivec3 wsgi_bufferPos_n;

                ivec3 face_dir;
                if      (localGeoNormal.x >  0.5) face_dir = ivec3( 1, 0, 0);
                else if (localGeoNormal.x < -0.5) face_dir = ivec3(-1, 0, 0);
                else if (localGeoNormal.z >  0.5) face_dir = ivec3( 0, 0, 1);
                else if (localGeoNormal.z < -0.5) face_dir = ivec3( 0, 0,-1);
                else if (localGeoNormal.y >  0.5) face_dir = ivec3( 0, 1, 0);
                else                              face_dir = ivec3( 0,-1, 0);

                vec3 wsgi_localPos = localPos - 0.02*localGeoNormal;

                for (int i = 0; i < WSGI_CASCADE_COUNT; i++) {
                    vec3 wsgi_bufferPos = wsgi_getBufferPosition(wsgi_localPos, i+WSGI_SCALE_BASE);
                    wsgi_bufferPos_n = ivec3(floor(wsgi_bufferPos)) + face_dir;

                    if (wsgi_isInBounds(wsgi_bufferPos_n)) {
                        wsgi_cascade = i;
                        break;
                    }
                }

                if (wsgi_cascade >= 0)
                    diffuse = wsgi_sample_nearest(wsgi_bufferPos_n, localTexNormal, wsgi_cascade) * BufferLumScale;
            }

            //diffuse = wsgi_sample(localPos + 0.1*localGeoNormal, localTexNormal);
        #endif

//        float wetnessDarkenF = wetness*porosity;
//        albedo.rgb *= 1.0 - 0.2*wetnessDarkenF;
//        albedo.rgb = pow(albedo.rgb, vec3(1.0 + 1.2*wetnessDarkenF));

        ApplyWetness_albedo(albedo.rgb, porosity, wetness);

        colorFinal.rgb = fma(diffuse, albedo.rgb, specular);
        //colorFinal = mix(albedo.rgb * diffuse, specular, view_F);
        colorFinal.a = 1.0;

        // float viewDist = length(localPos);
        // float fogF = smoothstep(fogStart, fogEnd, viewDist);
        // colorFinal = mix(colorFinal, fogColor.rgb, fogF);
    }

    #ifdef EFFECT_VL_ENABLED
        vec3 vlScatter = textureLod(texScatterVL, uv, 0).rgb;
        vec3 vlTransmit = textureLod(texTransmitVL, uv, 0).rgb;
        colorFinal.rgb = fma(colorFinal.rgb, vlTransmit, vlScatter * BufferLumScale);
    #endif

    vec4 particles = textureLod(texParticleOpaque, uv, 0);
    colorFinal.rgb = mix(colorFinal.rgb, particles.rgb * BufferLumScale, saturate(particles.a));

    colorFinal.rgb = clamp(colorFinal.rgb * BufferLumScaleInv, 0.0, 65000.0);

    outColor = colorFinal;
}
