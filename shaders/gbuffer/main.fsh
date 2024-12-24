#version 430

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outTexNormal;
layout(location = 2) out uvec4 outData;

in VertexData2 {
    vec2 uv;
    vec2 light;
    vec4 color;
    vec3 localPos;
    vec3 localOffset;
    vec3 localNormal;
    vec4 localTangent;
    flat uint blockId;

    #if defined RENDER_TRANSLUCENT && defined WATER_TESSELLATION_ENABLED
        vec3 surfacePos;
    #endif
} vIn;

#include "/settings.glsl"
#include "/lib/common.glsl"
#include "/lib/constants.glsl"

#include "/lib/material.glsl"

#ifdef RENDER_TRANSLUCENT
    #include "/lib/water_waves.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vIn.light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    #if MATERIAL_FORMAT != MAT_NONE
        vec4 normalData = iris_sampleNormalMap(mUV);
        vec4 specularData = iris_sampleSpecularMap(mUV);
    #endif

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);
    vec3 localGeoNormal = normalize(vIn.localNormal);

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
        // float emission = bitfieldExtract(vIn.material, 3, 1) != 0 ? 1.0 : 0.0;
        float emission = iris_getEmission(vIn.blockId) / 15.0;
        float porosity = 0.0;
        float sss = 0.0;

        emission *= lmcoord.x;
    #endif

    #if MATERIAL_FORMAT != MAT_NONE
        vec3 localBinormal = normalize(cross(vIn.localTangent.xyz, localGeoNormal) * vIn.localTangent.w);
        mat3 TBN = mat3(normalize(vIn.localTangent.xyz), localBinormal, localGeoNormal);

        localTexNormal = normalize(TBN * localTexNormal);
    #endif

    #ifdef RENDER_TRANSLUCENT
        // isWater = bitfieldExtract(vIn.material, 6, 1) != 0;
        bool is_fluid = iris_hasFluid(vIn.blockId);

        if (is_fluid) {
            #ifdef WATER_WAVES_ENABLED
                vec3 waveOffset = GetWaveHeight(vIn.surfacePos + cameraPos, lmcoord.y, timeCounter, WaterWaveOctaveMax);

                // mUV += 0.1*waveOffset.xz;

                vec3 wavePos = vIn.surfacePos;
                wavePos.y += waveOffset.y - vIn.localOffset.y;

                vec3 dX = dFdx(wavePos);
                vec3 dY = dFdy(wavePos);
                localTexNormal = normalize(cross(dX, dY));
            #endif

            // vec3 localViewDir = normalize(localPos);
            // float NoVm = max(dot(localNormal, -localViewDir), 0.0);
            // float F = F_schlick(NoVm, 0.02, 1.0);

            roughness = 0.02;
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

    outTexNormal = vec4((localTexNormal * 0.5 + 0.5), 1.0);

    outData.r = packUnorm4x8(vec4((localGeoNormal * 0.5 + 0.5), 0.0));
    outData.g = packUnorm4x8(vec4(roughness, f0_metal, emission, sss));
    outData.b = packUnorm4x8(vec4(lmcoord, occlusion, 0.0));
    outData.a = vIn.blockId;
}
