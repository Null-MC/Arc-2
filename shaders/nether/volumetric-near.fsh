#version 430 core

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec3 outScatter;
layout(location = 1) out vec3 outTransmit;

in vec2 uv;

uniform sampler2D mainDepthTex;

uniform sampler3D texFogNoise;
uniform sampler2D texBlueNoise;

#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_VL_SHADOWS)
    uniform samplerCubeArrayShadow pointLightFiltered;

    #ifdef LIGHTING_SHADOW_PCSS
        uniform samplerCubeArray pointLight;
    #endif
#endif

#ifdef FLOODFILL_ENABLED
    uniform sampler3D texFloodFill_final;
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

#include "/lib/voxel/voxel-common.glsl"

#include "/lib/light/volumetric.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/nether/smoke.glsl"

#if LIGHTING_MODE == LIGHT_MODE_RT || (LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED))
    #include "/lib/voxel/voxel-sample.glsl"
    #include "/lib/voxel/light-list.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_RT || LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #include "/lib/light/fresnel.glsl"
    #include "/lib/light/sampling.glsl"
    #include "/lib/light/meta.glsl"
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

//#include "/lib/vl-shared.glsl"

#ifdef VL_JITTER
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    const int uv_scale = int(exp2(LIGHTING_VL_RES));
    vec2 viewSize = ap.game.screenSize / uv_scale;

    #ifdef VL_JITTER
        vec2 uv2 = uv;
        jitter(uv2, viewSize);
        ivec2 uv_depth = ivec2(uv2 * ap.game.screenSize);
    #else
        ivec2 uv_depth = ivec2(uv * ap.game.screenSize);
    #endif

    float depth = texelFetch(mainDepthTex, uv_depth, 0).r;

    #ifdef EFFECT_TAA_ENABLED
        //float dither = InterleavedGradientNoiseTime(gl_FragCoord.xy);
        float dither = sample_blueNoise(gl_FragCoord.xy).x;
    #else
        float dither = InterleavedGradientNoise(gl_FragCoord.xy);
    #endif

    vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;
    vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
    vec3 localPos = mul3(ap.camera.viewInv, viewPos);

    float len = length(localPos);
    vec3 localViewDir = localPos / len;

    float far = ap.camera.far * 0.25;

    //if (depth >= 1.0 && len < far) len = far;

    float bias = len * 0.004;

    float renderDistSq = _pow2(ap.camera.renderDistance);

    vec3 sampleLocalPosLast = vec3(0.0);
    vec3 scattering = vec3(0.0);
    float transmittance = 1.0;

    vec3 traceEnd = clamp(len - bias, 0.0, far) * localViewDir;

    //float stepDist = length(traceEnd) / VL_maxSamples_near;

    const vec3 localPosStart = vec3(0.0);

    for (int i = 0; i < VL_maxSamples_near; i++) {
        float iF = min(i + dither, VL_maxSamples_near-1);
        float stepF = saturate(iF / (VL_maxSamples_near-1));
        stepF = pow(stepF, 2.2);

        vec3 sampleLocalPos = mix(localPosStart, traceEnd, stepF);

        float stepDist = length(sampleLocalPos - sampleLocalPosLast);

        float sampleDensity = SampleSmokeNoise(sampleLocalPos);
        sampleDensity *= Scene_SkyFogDensityF;

        vec3 sampleLit = vec3(0.0);

        #ifdef LIGHTING_VL_SHADOWS
            #if LIGHTING_MODE == LIGHT_MODE_SHADOWS
                const bool isInFluid = false;
                vec3 blockLight = sample_AllPointLights_VL(sampleLocalPos, isInFluid);
                sampleLit += blockLight * 8.0;
            #elif LIGHTING_MODE == LIGHT_MODE_RT
                vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);
                ivec3 lightBinPos = ivec3(floor(voxelPos / LIGHT_BIN_SIZE));
                int lightBinIndex = GetLightBinIndex(lightBinPos);
                uint binLightCount = LightBinMap[lightBinIndex].lightCount;

                vec3 jitter = hash33(vec3(gl_FragCoord.xy, ap.time.frames)) - 0.5;
                //vec3 jitter = sample_blueNoise(gl_FragCoord.xy) * 0.5;
                jitter *= Lighting_PenumbraSize;

                #if RT_MAX_SAMPLE_COUNT > 0
                    uint maxSampleCount = clamp(binLightCount, 0u, RT_MAX_SAMPLE_COUNT);
                    float bright_scale = binLightCount / float(RT_MAX_SAMPLE_COUNT);
                #else
                    uint maxSampleCount = clamp(binLightCount, 0u, RT_MAX_LIGHT_COUNT);
                    const float bright_scale = 1.0;
                #endif

                int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, ap.time.frames)));

                for (int i = 0; i < maxSampleCount; i++) {
                    int i2 = (i + i_offset) % int(binLightCount);

                    uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i2].voxelIndex;

                    vec3 light_voxelPos = GetLightVoxelPos(light_voxelIndex);
                    light_voxelPos += 0.5 + jitter;

                    vec3 light_LocalPos = voxel_getLocalPosition(light_voxelPos);

                    uint blockId = SampleVoxelBlockLocal(light_LocalPos);

                    float lightRange = iris_getEmission(blockId);
                    vec3 lightColor = iris_getLightColor(blockId).rgb;
                    vec3 light_hsv = RgbToHsv(lightColor);
                    lightColor = HsvToRgb(vec3(light_hsv.xy, lightRange/15.0));
                    lightColor = RgbToLinear(lightColor);

                    vec3 lightVec = light_LocalPos - sampleLocalPos;
                    float lightAtt = GetLightAttenuation(lightVec, lightRange);
                    //lightAtt *= light_hsv.z;

                    vec3 lightColorAtt = BLOCK_LUX * lightAtt * lightColor;

                    vec3 lightDir = normalize(lightVec);

                    float VoL = dot(localViewDir, lightDir);
                    float phase = saturate(getMiePhase(VoL));

                    vec3 traceStart = light_voxelPos;
                    vec3 traceEnd = voxelPos;
                    float traceRange = lightRange;
                    bool traceSelf = !iris_isFullBlock(blockId);

                    vec3 shadow_color = TraceDDA(traceStart, traceEnd, traceRange, traceSelf);

                    sampleLit += phase * shadow_color * lightColorAtt * bright_scale * 10.0;
                }
            #endif
        #endif

        #ifdef FLOODFILL_ENABLED
            vec3 voxelPos = voxel_GetBufferPosition(sampleLocalPos);

            if (floodfill_isInBounds(voxelPos)) {
                vec3 blockLight = floodfill_sample(voxelPos);
                sampleLit += phaseIso * blockLight;
            }
        #endif

//        #if LIGHTING_MODE == LIGHT_MODE_VANILLA
//            vec3 blockLighting = GetVanillaBlockLight(sample_lmcoord.x, 1.0);
//            sampleLit += phaseIso * blockLighting;
//        #endif


        float mieDensity = sampleDensity * stepDist + EPSILON;
        float mieScattering = mieScatteringF * mieDensity;
        float mieAbsorption = mieAbsorptionF * mieDensity;
        float extinction = mieScattering + mieAbsorption;

        float sampleTransmittance = exp(-extinction);

        vec3 ambient = 0.1 * RgbToLinear(vec3(0.678, 0.424, 0.294));

        vec3 mieInScattering = mieScattering * (ambient + sampleLit);

        vec3 scatteringIntegral = (mieInScattering - mieInScattering * sampleTransmittance) / extinction;

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;

        sampleLocalPosLast = sampleLocalPos;
    }

    outScatter = scattering * BufferLumScaleInv;
    outTransmit = vec3(transmittance);
}
