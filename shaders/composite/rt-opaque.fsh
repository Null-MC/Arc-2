#version 430 core
#extension GL_NV_gpu_shader5: enable

layout(location = 0) out vec4 outDiffuseRT;

uniform sampler2D solidDepthTex;
uniform usampler2D texDeferredOpaque_Data;
uniform sampler2D texDeferredOpaque_TexNormal;

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

#include "/lib/voxel/voxel_common.glsl"
#include "/lib/voxel/light-list.glsl"
#include "/lib/voxel/triangle-list.glsl"
#include "/lib/voxel/dda-trace.glsl"


void main() {
    ivec2 iuv = ivec2(uv * screenSize + 0.5);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;

    vec3 diffuseFinal = vec3(0.0);

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

            vec4 data_g = unpackUnorm4x8(data.g);
            float roughness = data_g.x;
            // float f0_metal = data_g.y;
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

            uint maxSampleCount = binLightCount; //min(binLightCount, 16u);

            for (int i = 0; i < maxSampleCount; i++) {
                uint light_voxelIndex = LightBinMap[lightBinIndex].lightList[i];

                vec3 light_voxelPos = GetVoxelPos(light_voxelIndex) + 0.5;
                light_voxelPos += jitter*0.5;

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

                vec3 origin = light_voxelPos;
                vec3 endPos = voxelPos_out;
                bool traceSelf = false;
                sampleDiffuse *= TraceDDA(origin, endPos, lightRange, traceSelf);

                diffuseFinal += sampleDiffuse;
            }
        }
    }

    outDiffuseRT = vec4(diffuseFinal, 1.0);
}
