#version 430 core

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

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#ifdef LPV_ENABLED
    #include "/lib/buffers/sh-lpv.glsl"
#endif

#include "/lib/noise/ign.glsl"
#include "/lib/hg.glsl"

#ifdef SHADOWS_ENABLED
    #include "/lib/shadow/csm.glsl"
    #include "/lib/shadow/sample.glsl"
#endif

#include "/lib/sky/common.glsl"
#include "/lib/sky/transmittance.glsl"
#include "/lib/sky/density.glsl"

#include "/lib/light/volumetric.glsl"

#ifdef LPV_ENABLED
    #include "/lib/voxel/voxel_common.glsl"
    #include "/lib/lpv/lpv_common.glsl"
    #include "/lib/lpv/lpv_sample.glsl"
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
        
        float lightStrength = Scene_LocalSunDir.y > 0.0 ? SUN_BRIGHTNESS : MOON_BRIGHTNESS;

        bool is_trans_fluid = iris_hasFluid(blockId); //unpackUnorm4x8(data_g).z > 0.5
        bool isWater = is_trans_fluid && ap.camera.fluid != 1;

        float phase_gF, phase_gB, phase_gM;
        vec3 scatterF, transmitF;
        vec3 sampleAmbient = vec3(0.0);

        if (isWater) {
            scatterF = VL_WaterScatter;
            transmitF = VL_WaterTransmit;
            phase_gF = VL_WaterPhaseF;
            phase_gB = VL_WaterPhaseB;
            phase_gM = VL_WaterPhaseM;

            sampleAmbient = VL_WaterAmbient * Scene_SkyIrradianceUp;
            sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth;
        }
        else {
//            scatterF = vec3(mix(VL_Scatter, VL_RainScatter, ap.world.rainStrength));
//            transmitF = vec3(mix(VL_Transmit, VL_RainTransmit, ap.world.rainStrength));
//            phase_gF = mix(VL_Phase, VL_RainPhase, ap.world.rainStrength);
//            phase_gB = -0.32;
//            phase_gM = 0.36;
//
//            sampleAmbient = vec3(VL_AmbientF * mix(Scene_SkyIrradianceUp, vec3(0.3), 0.8*ap.world.rainStrength));
            #if SKY_FOG_DENSITY == 0
                outScatter = vec3(0.0);
                outTransmit = vec3(1.0);
                return;
            #endif
        }

        //sampleAmbient *= phaseIso * Scene_SkyBrightnessSmooth;

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

        float miePhaseValue, rayleighPhaseValue;

        if (!isWater) {
            // TODO: add moon
            miePhaseValue = getMiePhase(VoL_sun);
            rayleighPhaseValue = getRayleighPhase(-VoL_sun);
        }

        // int material = int(unpackUnorm4x8(data_r).w * 255.0 + 0.5);
        // bool isWater = bitfieldExtract(material, 6, 1) != 0
        //     && ap.camera.fluid != 1;

        for (int i = 0; i < VL_MaxSamples; i++) {
            vec3 shadowSample = vec3(1.0);
            #ifdef SHADOWS_ENABLED
                const float shadowRadius = 2.0*shadowPixelSize;

                vec3 shadowViewPos = fma(shadowViewStep, vec3(i+dither), shadowViewStart);

                int shadowCascade;
                vec3 shadowPos = GetShadowSamplePos(shadowViewPos, shadowRadius, shadowCascade);
                shadowSample = SampleShadowColor(shadowPos, shadowCascade);
            #endif

            vec3 sampleLocalPos = fma(stepLocal, vec3(i+dither), localPosTrans);

//            vec3 skyPos = getSkyPosition(sampleLocalPos);
//            vec3 skyLighting = getValFromTLUT(texSkyTransmit, skyPos, Scene_LocalLightDir);
//            vec3 sampleColor = lightStrength * skyLighting * shadowSample;

            vec3 sunTransmit, moonTransmit;
            GetSkyLightTransmission(sampleLocalPos, sunTransmit, moonTransmit);
            vec3 sunSkyLight = SUN_LUMINANCE * sunTransmit;
            vec3 moonSkyLight = MOON_BRIGHTNESS * moonTransmit;

            float sampleDensity = 1.0;
            if (!isWater) {
                sampleDensity = GetSkyDensity(sampleLocalPos);

//                float worldY = sampleLocalPos.y + ap.camera.pos.y;
//                float lightAtmosDist = max(SKY_SEA_LEVEL + 200.0 - worldY, 0.0) / Scene_LocalLightDir.y;
//                shadowSample *= exp2(-0.16 * lightAtmosDist * transmitF);
            }

//            vec3 sampleLit = phase * sampleColor + sampleAmbient;
//            vec3 sampleTransmit = exp(-sampleDensity * transmitF);
            //vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
            vec3 sampleLit = vec3(0.0);//fma(sampleColor, shadowSample, sampleAmbient);
            //vec3 sampleTransmit = exp(-sampleDensity * transmitF);

            #ifdef LPV_ENABLED
                vec3 voxelPos = GetVoxelPosition(sampleLocalPos);
                if (IsInVoxelBounds(voxelPos)) {
                    vec3 blockLight = sample_lpv_linear(voxelPos, localViewDir);
                    sampleLit += blockLight; // * phaseIso
                }
            #endif

//            transmittance *= sampleTransmit;
//            scattering += scatterF * transmittance * sampleLit * sampleDensity;



            vec3 scatteringIntegral, sampleTransmittance, inScattering, extinction;
            if (!isWater) {
                vec3 skyPos = getSkyPosition(sampleLocalPos);

                float mieDensity = sampleDensity;
                float mieScattering = 0.0004 * mieDensity;
                float mieAbsorption = 0.0020 * mieDensity;
                extinction = vec3(mieScattering + mieAbsorption);

                sampleTransmittance = exp(-extinction * stepDist);

                vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
                psiMS *= SKY_LUMINANCE * Scene_SkyBrightnessSmooth;

                // TODO: add moon
                vec3 mieInScattering = mieScattering * (miePhaseValue * sunSkyLight * shadowSample + psiMS + sampleLit);
                inScattering = mieInScattering;
            }
            else {
                vec3 sampleColor = (phase_sun * sunSkyLight) + (phase_moon * moonSkyLight);
                sampleLit += fma(sampleColor, shadowSample, sampleAmbient);

                extinction = transmitF + scatterF;

                sampleTransmittance = exp(-sampleDensity * stepDist * extinction);

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
