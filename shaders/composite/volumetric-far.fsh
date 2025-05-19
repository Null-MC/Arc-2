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
uniform sampler2D texSkyTransmit;
uniform sampler2D texSkyMultiScatter;

#ifdef SHADOWS_ENABLED
    uniform sampler2DArray shadowMap;
    uniform sampler2DArray solidShadowMap;
    uniform sampler2DArray texShadowColor;
#endif

#if LIGHTING_MODE == LIGHT_MODE_LPV
    uniform sampler3D texFloodFill;
    uniform sampler3D texFloodFill_alt;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/hsv.glsl"

#ifdef SHADOWS_ENABLED
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

#if LIGHTING_MODE == LIGHT_MODE_LPV
    #include "/lib/voxel/voxel_common.glsl"
    #include "/lib/lpv/floodfill.glsl"
#endif

const int VL_MaxSamples = 16;


void main() {
    const float stepScale = 1.0 / VL_MaxSamples;

    ivec2 iuv = ivec2(uv * ap.game.screenSize);

    float depthOpaque = textureLod(solidDepthTex, uv, 0).r;
    float depthTrans = textureLod(mainDepthTex, uv, 0).r;

    vec3 scattering = vec3(0.0);
    vec3 transmittance = vec3(1.0);

    if (depthTrans < depthOpaque) {
        uint blockId = texelFetch(texDeferredTrans_Data, iuv, 0).a;

        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        #else
            float dither = InterleavedGradientNoise(gl_FragCoord.xy);
        #endif
        
        //float lightStrength = Scene_LocalSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;

        bool is_trans_fluid = iris_hasFluid(blockId); //unpackUnorm4x8(data_g).z > 0.5
        bool isWater = is_trans_fluid && ap.camera.fluid != 1;

        float phase_gF, phase_gB, phase_gM;
        vec3 scatterF, transmitF;
        vec3 ambientBase = vec3(0.0);

        if (isWater) {
            scatterF = VL_WaterScatter;
            transmitF = VL_WaterTransmit;
            phase_gF = VL_WaterPhaseF;
            phase_gB = VL_WaterPhaseB;
            phase_gM = VL_WaterPhaseM;

            ambientBase = VL_WaterAmbient * Scene_SkyIrradianceUp;
            //ambientBase *= Scene_SkyBrightnessSmooth;
        }
        else {
            scatterF = vec3(0.0);
            transmitF = vec3(1.0);
            phase_gF = 0.0;
            phase_gB = 0.0;
            phase_gM = 0.0;
//            scatterF = vec3(mix(VL_Scatter, VL_RainScatter, ap.world.rain));
//            transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, ap.world.rain));
//            phase_gF = mix(VL_Phase, VL_RainPhase, ap.world.rain);
//            phase_gB = -0.32;
//            phase_gM = 0.36;
//
//            ambientBase = vec3(VL_AmbientF * mix(Scene_SkyIrradianceUp, vec3(0.3), 0.8*ap.world.rain));
            if (Scene_SkyFogDensityF < EPSILON) {
                outScatter = vec3(0.0);
                outTransmit = vec3(1.0);
                return;
            }
        }

        //ambientBase *= phaseIso * Scene_SkyBrightnessSmooth;

        vec3 ndcPos = fma(vec3(uv, depthOpaque), vec3(2.0), vec3(-1.0));
        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPosOpaque = mul3(ap.camera.viewInv, viewPos);
        
        float len = length(localPosOpaque);
        float far = ap.camera.far * 0.5;
        
        if (len > far)
            localPosOpaque = localPosOpaque / len * far;

        ndcPos = fma(vec3(uv, depthTrans), vec3(2.0), vec3(-1.0));
        viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPosTrans = mul3(ap.camera.viewInv, viewPos);

        vec3 localRay = localPosOpaque - localPosTrans;
        vec3 stepLocal = localRay * stepScale;
        float stepDist = length(stepLocal);

        vec3 localViewDir = normalize(localPosOpaque);
//        float VoL = dot(localViewDir, Scene_LocalLightDir);
//        float phase = HG(VoL, phase_g);
        float VoL_sun = dot(localViewDir, Scene_LocalSunDir);
        float phase_sun = DHG(VoL_sun, phase_gB, phase_gF, phase_gM);
        float VoL_moon = dot(localViewDir, -Scene_LocalSunDir);
        float phase_moon = DHG(VoL_moon, phase_gB, phase_gF, phase_gM);

        vec3 shadowViewStart = mul3(ap.celestial.view, localPosTrans);
        vec3 shadowViewEnd = mul3(ap.celestial.view, localPosOpaque);
        vec3 shadowViewStep = (shadowViewEnd - shadowViewStart) * stepScale;

        float miePhaseValue = 0.0;// rayleighPhaseValue;

        if (!isWater) {
            // TODO: add moon
            miePhaseValue = getMiePhase(VoL_sun);
            //rayleighPhaseValue = getRayleighPhase(-VoL_sun);
        }

        // int material = int(unpackUnorm4x8(data_r).w * 255.0 + 0.5);
        // bool isWater = bitfieldExtract(material, 6, 1) != 0
        //     && ap.camera.fluid != 1;

        for (int i = 0; i < VL_MaxSamples; i++) {
            float waterDepth = EPSILON;
            vec3 shadowSample = vec3(1.0);
            #ifdef SHADOWS_ENABLED
                const float shadowRadius = 2.0*shadowPixelSize;

                vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

                int shadowCascade;
                vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);

                shadowSample = SampleShadowColor(shadowPos, shadowCascade, waterDepth);
                waterDepth = max(waterDepth, EPSILON);
            #endif

            vec3 sampleLocalPos = fma(stepLocal, vec3(i+dither), localPosTrans);

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
            vec3 sunSkyLight = skyLightF * SUN_LUX * sunTransmit;
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

            float sampleDensity = VL_WaterDensity;
            if (!isWater) {
                sampleDensity = GetSkyDensity(sampleLocalPos);

//                float worldY = sampleLocalPos.y + ap.camera.pos.y;
//                float lightAtmosDist = max(SKY_SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
//                shadowSample *= exp2(-0.16 * lightAtmosDist * transmitF);
            }

//            vec3 sampleLit = phase * sampleColor + ambientBase;
//            vec3 sampleTransmit = exp(-sampleDensity * transmitF);
            //vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = vec3(0.0);//fma(sampleColor, shadowSample, ambientBase);
            //vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            #if LIGHTING_MODE == LIGHT_MODE_LPV
                vec3 voxelPos = GetVoxelPosition(sampleLocalPos);

                if (IsInVoxelBounds(voxelPos)) {
                    vec3 blockLight = sample_floodfill(voxelPos);
                    sampleLit += phaseIso * blockLight;
                }
            #endif


            vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;

            if (!isWater) {
                vec3 skyPos = getSkyPosition(sampleLocalPos);

                float mieDensity = max(sampleDensity, EPSILON);
                float mieScattering = mieScatteringF * mieDensity;
                float mieAbsorption = mieAbsorptionF * mieDensity;
                extinction = vec3(mieScattering + mieAbsorption);

                sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                psiMS *= Scene_SkyBrightnessSmooth;

                // TODO: add moon
                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
                inScattering = mieInScattering;
            }
            else {
                ivec3 blockWorldPos = ivec3(floor(sampleLocalPos + ap.camera.pos));
                uint blockLightData = iris_getBlockAtPos(blockWorldPos).y;
                uint blockSkyLight = bitfieldExtract(blockLightData, 16, 16);
                vec3 sampleAmbient = ambientBase * (blockSkyLight/240.0);

                extinction = transmitF + scatterF;

                shadowSample *= exp(-0.8*waterDepth * sampleDensity * extinction);

                sampleTransmittance = exp(-stepDist * sampleDensity * extinction);

                vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
                sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

                inScattering = scatterF * sampleLit * sampleDensity;
            }

            scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

            scattering += scatteringIntegral * transmittance;
            transmittance *= sampleTransmittance;
        }

//        scattering = vec3(10.0);
    }

    outScatter = scattering;
    outTransmit = transmittance;
}
