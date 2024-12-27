#version 430 core
#extension GL_NV_gpu_shader5: enable

layout(location = 0) out vec4 outDiffuseRT;
layout(location = 1) out vec4 outSpecularRT;

uniform sampler2D solidDepthTex;
uniform sampler2D texDeferredOpaque_Color;
uniform usampler2D texDeferredOpaque_Data;
uniform sampler2D texDeferredOpaque_TexNormal;

uniform sampler2D blockAtlas;

layout(r32ui) uniform readonly uimage3D imgVoxelBlock;

in vec2 uv;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/buffers/light-list.glsl"
#include "/lib/buffers/triangle-list.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"

#include "/lib/material_fresnel.glsl"

#include "/lib/voxel/voxel_common.glsl"
#include "/lib/voxel/light-list.glsl"
#include "/lib/voxel/triangle-list.glsl"
#include "/lib/voxel/dda-trace.glsl"


#define MAX_SAMPLE_COUNT 2u


void main() {
    ivec2 iuv = ivec2(uv * screenSize + 0.5);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 diffuseFinal = vec3(0.0);
    vec3 specularFinal = vec3(0.0);

    if (depth < 1.0) {
        uvec4 data = texelFetch(texDeferredOpaque_Data, iuv, 0);
        // vec2 pixelSize = 1.0 / screenSize;

        vec3 clipPos = vec3(uv, depth) * 2.0 - 1.0;
        vec3 viewPos = unproject(playerProjectionInverse, clipPos);
        vec3 localPos = mul3(playerModelViewInverse, viewPos);

        // float viewDist = length(viewPos);

        vec3 normalData = texelFetch(texDeferredOpaque_TexNormal, iuv, 0).xyz;
        vec3 localTexNormal = normalize(normalData * 2.0 - 1.0);

        // vec3 viewNormal = mat3(playerModelView) * localNormal;

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

            float roughL = roughness*roughness;

            ivec3 lightBinPos = ivec3(floor(voxelPos_in / LIGHT_BIN_SIZE));
            int lightBinIndex = GetLightBinIndex(lightBinPos);
            uint binLightCount = LightBinMap[lightBinIndex].lightCount;

            vec3 localViewDir = normalize(-localPos);

            vec3 jitter = hash33(vec3(gl_FragCoord.xy, frameCounter)) - 0.5;

            // voxelPos = GetVoxelPosition(localPos + 0.02*localGeoNormal);
            vec3 voxelPos_out = voxelPos + 0.02*localGeoNormal;

            #if MAX_SAMPLE_COUNT > 0
                uint maxSampleCount = min(binLightCount, MAX_SAMPLE_COUNT);
                float bright_scale = ceil(binLightCount / float(MAX_SAMPLE_COUNT));
            #else
                uint maxSampleCount = binLightCount;
                const float bright_scale = 1.0;
            #endif

            int i_offset = int(binLightCount * hash13(vec3(gl_FragCoord.xy, frameCounter)));

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
                float NoVm = max(dot(localTexNormal, localViewDir), 0.0);

                if (NoLm == 0.0 || dot(localGeoNormal, lightDir) <= 0.0) continue;
                float D = SampleLightDiffuse(NoVm, NoLm, LoHm, roughL);
                vec3 sampleDiffuse = (NoLm * lightAtt.x * D) * lightColor;

                float NoHm = max(dot(localTexNormal, H), 0.0);

                const bool isUnderWater = false;
                vec3 F = material_fresnel(albedo.rgb, f0_metal, roughL, NoVm, isUnderWater);
                vec3 S = SampleLightSpecular(NoLm, NoHm, LoHm, F, roughL);
                vec3 sampleSpecular = lightAtt.y * S * lightColor;

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
        }
    }

    outDiffuseRT = vec4(diffuseFinal, 1.0);
    outSpecularRT = vec4(specularFinal, 1.0);
}
