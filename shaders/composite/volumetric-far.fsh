#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;
uniform sampler2D solidDepthTex;
uniform usampler2D texDeferredTrans_Data;

uniform sampler3D texFogNoise;
uniform sampler2D texBlueNoise;
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyMultiScatter;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowBlocker;
    uniform sampler2DArray texShadowColor;
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_VL_SHADOWS)
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

#if !defined(VOXEL_PROVIDED)
    #include "/lib/buffers/voxel-block.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
    #include "/lib/buffers/light-list.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"
#include "/lib/noise/blue.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/hsv.glsl"
#include "/lib/utility/tbn.glsl"
#include "/lib/utility/matrix.glsl"
//#include "/lib/utility/blackbody.glsl"

#ifdef SHADOWS_ENABLED
    #ifdef SHADOW_DISTORTION_ENABLED
        #include "/lib/shadow/distorted.glsl"
    #endif

    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#include "/lib/light/volumetric.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/clouds.glsl"

#if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
    #include "/lib/shadow/clouds.glsl"
#endif

#include "/lib/voxel/voxel-common.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
    #include "/lib/voxel/voxel-sample.glsl"
    #include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #include "/lib/light/fresnel.glsl"
    #include "/lib/light/sampling.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_VL_SHADOWS)
    #include "/lib/shadow-point/common.glsl"
    #include "/lib/shadow-point/sample-common.glsl"
    #include "/lib/shadow-point/sample-vl.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_RT && defined(LIGHTING_VL_SHADOWS)
    #include "/lib/voxel/dda.glsl"
    #include "/lib/voxel/light-trace.glsl"
#elif LIGHTING_MODE == LIGHT_MODE_VANILLA
    #include "/lib/utility/blackbody.glsl"
    #include "/lib/lightmap/sample.glsl"
#endif

#ifdef FLOODFILL_ENABLED
    #include "/lib/voxel/floodfill-common.glsl"
    #include "/lib/voxel/floodfill-sample.glsl"
#endif

#include "/lib/vl-shared.glsl"


void main() {
    const float stepScale = 1.0 / VL_maxSamples_far;

    ivec2 iuv = ivec2(uv * ap.game.screenSize);

    float depthOpaque = textureLod(solidDepthTex, uv, 0).r;
    float depthTrans = textureLod(mainDepthTex, uv, 0).r;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    //if (depthTrans < depthOpaque) {
        uint blockId = texelFetch(texDeferredTrans_Data, iuv, 0).a;

        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
        
        //float lightStrength = Scene_LocalSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;

        bool is_trans_fluid = iris_hasFluid(blockId); //unpackUnorm4x8(data_g).z > 0.5
        bool isWater = is_trans_fluid && ap.camera.fluid != 1;

        vec3 waterAmbientBase = VL_WaterAmbient * Scene_SkyIrradianceUp;

//        if (Scene_SkyFogDensityF < EPSILON) {
//            outScatter = vec3(0.0);
//            outTransmit = vec3(1.0);
//            return;
//        }

        //ambientBase *= phaseIso * Scene_SkyBrightnessSmooth;

        vec3 ndcPos = fma(vec3(uv, depthOpaque), vec3(2.0), vec3(-1.0));
        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPosOpaque = mul3(ap.camera.viewInv, viewPos);

        float len = length(localPosOpaque);
        float far = 256.0;//ap.camera.far * 0.5;

        if (depthTrans >= 1.0 && len < far) len = far;
        
        if (len > far)
            localPosOpaque = localPosOpaque / len * far;

        ndcPos = fma(vec3(uv, depthTrans), vec3(2.0), vec3(-1.0));
        viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPosTrans = mul3(ap.camera.viewInv, viewPos);

        vec3 localViewDir = normalize(localPosOpaque);
//        float VoL = dot(localViewDir, Scene_LocalLightDir);
//        float phase = HG(VoL, phase_g);
        float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
        float phase_sun = DHG(VoL_sun, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);
        float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
        float phase_moon = DHG(VoL_moon, VL_WaterPhaseB, VL_WaterPhaseF, VL_WaterPhaseM);

        float miePhase_sun = getMiePhase(VoL_sun, 0.2);
        float miePhase_moon = getMiePhase(VoL_moon, 0.2);

        #ifdef SKY_CLOUDS_ENABLED
            vec3 cloud_localPos;
            float cloudDensity, cloud_shadowSun, cloud_shadowMoon;
            vl_sampleClouds(localViewDir, cloud_localPos, cloudDensity, cloud_shadowSun, cloud_shadowMoon);
        #endif

    if (depthTrans < depthOpaque) {
        vec3 localRay = localPosOpaque - localPosTrans;
        vec3 stepLocal = localRay * stepScale;
        float stepDist = length(stepLocal);

        vec3 shadowViewStart = mul3(ap.celestial.view, localPosTrans);
        vec3 shadowViewEnd = mul3(ap.celestial.view, localPosOpaque);
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

        // int material = int(unpackUnorm4x8(data_r).w * 255.0 + 0.5);
        // bool isWater = bitfieldExtract(material, 6, 1) != 0
        //     && ap.camera.fluid != 1;

        for (int i = 0; i < VL_maxSamples_far; i++) {
            vec3 sampleLocalPos = fma(stepLocal, vec3(i+dither), localPosTrans);
            vec2 sample_lmcoord = vec2(0.0, 1.0);

            #ifdef VOXEL_PROVIDED
                ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));

                bool isFluid = false;
                if (blockWorldPos.y > -64 && blockWorldPos.y < 320) { // && lengthSq(sampleLocalPos) < renderDistSq) {
                    uint blockId = iris_getBlockAtPos(blockWorldPos).x;
                    isFluid = iris_hasFluid(blockId) && iris_getEmission(blockId) == 0;

                    uint blockLightData = iris_getBlockAtPos(blockWorldPos).y;

                    uvec2 blockLightInt = uvec2(
                        bitfieldExtract(blockLightData,  0, 16),
                        bitfieldExtract(blockLightData, 16, 16));

                    sample_lmcoord = saturate(blockLightInt / 240.0);
                }

                if (isFluid) {
                    uint blockLightData = iris_getBlockAtPos(blockWorldPos).y;

                    uvec2 blockLightInt = uvec2(
                        bitfieldExtract(blockLightData, 0, 16),
                        bitfieldExtract(blockLightData, 16, 16));

                    sample_lmcoord = saturate(blockLightInt / 240.0);
                }
            #else
                bool isFluid = isWater;
            #endif

            float waterDepth = EPSILON;
            vec3 shadowSample = vec3(sample_lmcoord.y);
            #ifdef SHADOWS_ENABLED
                const float shadowRadius = 2.0*shadowPixelSize;

                vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

                int shadowCascade;
                vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

                shadowSample = SampleShadowColor(shadowPos, shadowCascade, waterDepth);
                waterDepth = max(waterDepth, EPSILON);
            #endif

//            vec3 skyPos = getSkyPosition(sampleLocalPos);
//            vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalLightDir);
//            vec3 sampleColor = lightStrength * skyLighting * shadowSample;

            float skyLightF = smoothstep(0.0, 0.2, Scene_LocalLightDir.y);

            #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
                skyLightF *= SampleCloudShadows(sampleLocalPos);
            #endif

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
//            float skyLightF = smoothstep(0.0, 0.2, Scene_LocalLightDir.y);
            vec3 sunSkyLight = skyLightF * SUN_LUX * sunTransmit * Scene_SunColor;
            vec3 moonSkyLight = skyLightF * MOON_LUX * moonTransmit;

//            #if defined(SKY_CLOUDS_ENABLED) && defined(SHADOWS_CLOUD_ENABLED)
//                // Cloud Shadows
//                if (sampleLocalPos.y+ap.camera.pos.y < cloudHeight) {
//                    vec3 worldPos = sampleLocalPos + ap.camera.pos;
//                    worldPos += (cloudHeight - worldPos.y) / Scene_LocalLightDir.y * Scene_LocalLightDir;
//
//                    float cloudShadowDensity = SampleCloudDensity(worldPos) * 100.0;
//                    shadowSample *= mix(1.0, exp(-VL_ShadowTransmit * cloudShadowDensity), cloudShadowF);
//                }
//            #endif

            float vs_shadowF = 1.0;
            float sampleDensity = VL_WaterDensity;
            if (!isFluid) {
                sampleDensity = GetSkyDensity(sampleLocalPos);

                // TODO: cloud shadows & fog noise

                #ifdef VL_SELF_SHADOW
                    float shadow_dither = dither;

                    float shadowStepDist = 1.0;
                    float shadowDensity = 0.0;
                    for (float ii = shadow_dither; ii < 8.0; ii += 1.0) {
                        vec3 fogShadow_localPos = (shadowStepDist * ii) * Scene_LocalLightDir + sampleLocalPos;

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
                        vs_shadowF *= exp(-VL_ShadowTransmit * shadowDensity);
                        shadowSample *= vs_shadowF;
                    }
                #endif
            }

//            vec3 sampleLit = phase * sampleColor + ambientBase;
//            vec3 sampleTransmit = exp(-sampleDensity * transmitF);
            //vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = vec3(0.0);//fma(sampleColor, shadowSample, ambientBase);
            //vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            #ifdef LIGHTING_VL_SHADOWS
                #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
                    vec3 blockLight = sample_AllPointLights_VL(sampleLocalPos, isFluid);
                    sampleLit += blockLight;
                #elif LIGHTING_MODE == LIGHT_MODE_RT
                    // TODO: ?
                #endif
            #endif

            #ifdef FLOODFILL_ENABLED
                vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

                if (floodfill_isInBounds(voxelPos)) {
                    vec3 blockLight = floodfill_sample(voxelPos);

                    #if LIGHTING_MODE != LIGHT_MODE_LPV
                        blockLight *= (1.0/15.0);
                    #endif

                    sampleLit += phaseIso * blockLight;
                }
            #endif

            #if LIGHTING_MODE == LIGHT_MODE_VANILLA
                vec3 blockLighting = GetVanillaBlockLight(sample_lmcoord.x, 1.0);
                sampleLit += phaseIso * blockLighting;
            #endif

            vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;

            //sampleLit *= 8.0;

            if (!isFluid) {
                vec3 skyPos = getSkyPosition(sampleLocalPos);

                float mieDensity = sampleDensity + EPSILON;
                float mieScattering = mieScatteringF * mieDensity;
                float mieAbsorption = mieAbsorptionF * mieDensity;
                extinction = vec3(mieScattering + mieAbsorption);

                sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                vec3 ambient = psiMS * Scene_SkyBrightnessSmooth + VL_MinLight;

                vec3 mieSkyLight = miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight;
                vec3 mieInScattering = mieScattering * (mieSkyLight * shadowSample + ambient + sampleLit);
                inScattering = mieInScattering;
            }
            else {
                #ifdef VOXEL_PROVIDED
                    vec3 sampleAmbient = waterAmbientBase * sample_lmcoord.y;
                #else
                    vec3 sampleAmbient = waterAmbientBase * Scene_SkyBrightnessSmooth;
                #endif

                extinction = (VL_WaterTransmit + VL_WaterScatter) * sampleDensity;

                sampleTransmittance = exp(-stepDist * extinction);

                vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
                sampleColor *= exp(-waterDepth * extinction);
                sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

                inScattering = VL_WaterScatter * sampleLit * sampleDensity;
            }

            scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;
        }
    }

    #ifdef SKY_CLOUDS_ENABLED
        if (depthOpaque == 1.0) {
            float endWorldY = localPosOpaque.y + ap.camera.pos.y;
            //endWorldY -= (1.0-dither) * stepLocal.y;

            if (endWorldY < cloudHeight && cloudDensity > 0.0)
                vl_renderClouds(transmittance, scattering, miePhase_sun, miePhase_moon, cloud_localPos, cloudDensity, cloud_shadowSun, cloud_shadowMoon);
        }
    #endif

    outScatter = scattering * 0.001;
    outTransmit = transmittance;
}
