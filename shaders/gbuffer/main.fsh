#version 430

layout(location = 0) out vec4 outColor;
layout(location = 1) out uvec4 outData;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localOffset;
in vec3 localNormal;
in vec4 localTangent;
// in vec3 shadowViewPos;
flat in int material;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/constants.glsl"

// #include "/lib/light/hcm.glsl"
// #include "/lib/light/fresnel.glsl"
#include "/lib/material.glsl"

#ifdef RENDER_TRANSLUCENT
    #include "/lib/water_waves.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    #if MATERIAL_FORMAT != MAT_NONE
        vec4 normalData = iris_sampleNormalMap(mUV);
        vec4 specularData = iris_sampleSpecularMap(mUV);
    #endif

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    vec3 localGeoNormal = normalize(localNormal);

    #if MATERIAL_FORMAT == MAT_LABPBR
        vec3 localTexNormal = mat_normal_lab(normalData.xy);
        float occlusion = normalData.z;

        float roughness = mat_roughness(specularData.r);
        float f0_metal = specularData.g;
        float emission = mat_emission_lab(specularData.a);
        float porosity = mat_porosity_lab(specularData.b);
        float sss = mat_sss_lab(specularData.b);
    #elif MATERIAL_FORMAT == MAT_OLDPBR
        vec3 localTexNormal = mat_normal_old(normalData.xyz);
        float occlusion = 1.0;

        float roughness = mat_roughness(specularData.r);
        float f0_metal = specularData.g;
        float emission = specularData.b;
        float porosity = 0.0;
        float sss = 0.0;
    #else
        vec3 localTexNormal = localGeoNormal;
        float occlusion = 1.0;

        float roughness = 0.92;
        float f0_metal = 0.0;
        float emission = bitfieldExtract(material, 3, 1) != 0 ? 1.0 : 0.0;
        float porosity = 0.0;
        float sss = 0.0;

        emission *= lmcoord.x;
    #endif

    #if MATERIAL_FORMAT != MAT_NONE
        vec3 localBinormal = normalize(cross(localTangent.xyz, localGeoNormal) * localTangent.w);
        mat3 TBN = mat3(normalize(localTangent.xyz), localBinormal, localGeoNormal);

        localTexNormal = normalize(TBN * localTexNormal);
    #endif

    bool isWater = false;
    #ifdef RENDER_TRANSLUCENT
        isWater = bitfieldExtract(material, 6, 1) != 0;

        if (isWater) {
            #ifdef WATER_WAVES_ENABLED
                vec3 waveOffset = GetWaveHeight(localPos + cameraPos, lmcoord.y, timeCounter, WaterWaveOctaveMax);

                // mUV += 0.1*waveOffset.xz;

                vec3 wavePos = localPos;
                wavePos.y += waveOffset.y - localOffset.y;

                vec3 dX = dFdx(wavePos);
                vec3 dY = dFdy(wavePos);
                localTexNormal = normalize(cross(dX, dY));
            #endif

            // vec3 localViewDir = normalize(localPos);
            // float NoVm = max(dot(localNormal, -localViewDir), 0.0);
            // float F = F_schlick(NoVm, 0.02, 1.0);

            albedo.a = 0.02; //F;
        }
    #endif

    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    #ifndef RENDER_TRANSLUCENT
        albedo.a = 1.0;
    #endif

    outColor = albedo;

    outData.r = packUnorm4x8(vec4(localGeoNormal * 0.5 + 0.5, (material + 0.5) / 255.0));
    outData.g = packUnorm4x8(vec4(lmcoord, (isWater ? 1.0 : 0.0), 0.0));
    outData.b = packUnorm4x8(vec4((localTexNormal * 0.5 + 0.5), occlusion));
    outData.a = packUnorm4x8(vec4(roughness, f0_metal, emission, sss));
}
