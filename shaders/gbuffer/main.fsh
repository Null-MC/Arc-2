#version 450

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outTexNormal;
layout(location = 2) out uvec4 outData;

#if defined RENDER_PARALLAX && defined MATERIAL_PARALLAX_DEPTHWRITE
    layout (depth_greater) out float gl_FragDepth;
#endif

uniform sampler3D texFogNoise;

in VertexData2 {
    vec2 uv;
    vec2 light;
    vec4 color;
    vec3 localPos;
    vec3 localOffset;
    vec3 localNormal;
    vec4 localTangent;
    flat uint blockId;

    #if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
        //#ifdef WATER_TESSELLATION_ENABLED
            vec3 surfacePos;
        //#endif

        float waveStrength;
    #endif

    #if defined(RENDER_PARALLAX) || defined(MATERIAL_NORMAL_SMOOTH)
        vec3 tangentViewPos;
        flat vec2 atlasCoordMin;
        flat vec2 atlasCoordSize;
    #endif
} vIn;

#include "/lib/common.glsl"

#include "/lib/utility/tbn.glsl"

#include "/lib/material/material.glsl"

#include "/lib/sampling/atlas.glsl"
#include "/lib/sampling/lightmap.glsl"

#ifdef MATERIAL_NORMAL_SMOOTH
    #include "/lib/sampling/linear.glsl"
#endif

#ifdef RENDER_PARALLAX
    #include "/lib/material/parallax.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_VANILLA
    #include "/lib/lightmap/directional.glsl"
#endif

#ifdef FANCY_LAVA
    #include "/lib/noise/hash.glsl"
    #include "/lib/utility/blackbody.glsl"
    #include "/lib/lava.glsl"
#endif

#if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
    #include "/lib/water_waves.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vIn.light;
    vec4 mColor = vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    float mLOD = textureQueryLod(irisInt_BaseTex, mUV).y;

    #ifdef RENDER_PARALLAX
        float texDepth = 1.0;
        vec3 traceCoordDepth = vec3(1.0);

        float viewDist = length(vIn.localPos);
        vec3 tanViewDir = normalize(vIn.tangentViewPos);
        bool skipParallax = false;

        if (!skipParallax && viewDist < MATERIAL_PARALLAX_MAXDIST) {
            vec2 localCoord = GetLocalCoord(mUV, vIn.atlasCoordMin, vIn.atlasCoordSize);
            mUV = GetParallaxCoord(localCoord, mLOD, tanViewDir, viewDist, texDepth, traceCoordDepth);

            #ifdef MATERIAL_PARALLAX_DEPTHWRITE
                float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);

                if (pomDist > 0.0) {
                    vec3 viewPos = mul3(ap.camera.view, vIn.localPos);
                    float depth = -viewPos.z + pomDist * ParallaxDepthF;
                    gl_FragDepth = 0.5 * (-ap.camera.projection[2].z*depth + ap.camera.projection[3].z) / depth + 0.5;
                }
                else {
                    gl_FragDepth = gl_FragCoord.z;
                }
            #endif
        }
        #ifdef MATERIAL_PARALLAX_DEPTHWRITE
            else {
                gl_FragDepth = gl_FragCoord.z;
            }
        #endif
    #endif

    vec4 albedo = iris_sampleBaseTexLod(mUV, int(mLOD));

//    #if MATERIAL_NORMAL_FORMAT != MAT_NONE
        #ifdef MATERIAL_NORMAL_SMOOTH
            vec2 atlasSize = textureSize(irisInt_NormalMap, 0);

            //vec2 uv_min = floor(mUV * atlasSize) / atlasSize;
            vec2 uv[4];
            //vec2 atlasTileSize = vIn.atlasCoordSize * atlasSize;
            vec2 f = GetLinearCoords(mUV - 0.5/atlasSize, atlasSize, uv);

//            uv[0] = GetLocalCoord(uv[0], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[1] = GetLocalCoord(uv[1], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[2] = GetLocalCoord(uv[2], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[3] = GetLocalCoord(uv[3], vIn.atlasCoordMin, vIn.atlasCoordSize);
//
//            uv[0] = GetAtlasCoord(uv[0], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[1] = GetAtlasCoord(uv[1], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[2] = GetAtlasCoord(uv[2], vIn.atlasCoordMin, vIn.atlasCoordSize);
//            uv[3] = GetAtlasCoord(uv[3], vIn.atlasCoordMin, vIn.atlasCoordSize);

            vec2 uv_min = vIn.atlasCoordMin + 0.5/atlasSize;
            vec2 uv_max = vIn.atlasCoordMin + vIn.atlasCoordSize - 1.0/atlasSize;
            uv[0] = clamp(uv[0], uv_min, uv_max);
            uv[1] = clamp(uv[1], uv_min, uv_max);
            uv[2] = clamp(uv[2], uv_min, uv_max);
            uv[3] = clamp(uv[3], uv_min, uv_max);

            vec4 normalData;
            normalData.rgb = TextureLodLinearRGB(irisInt_NormalMap, uv, mLOD, f);
            normalData.a = iris_sampleNormalMapLod(mUV, int(mLOD)).a;
        #else
            vec4 normalData = iris_sampleNormalMapLod(mUV, int(mLOD));
        #endif
//    #else
//        vec4 normalData = vec4(0.5, 0.5, 1.0, 1.0);
//    #endif

    vec4 specularData = iris_sampleSpecularMapLod(mUV, int(mLOD));

    vec2 lmcoord = LightMapNorm(mLight);
    vec3 localGeoNormal = normalize(vIn.localNormal);

    vec3 localTexNormal = mat_normal(normalData.xyz);
    float roughness = mat_roughness(specularData.r);
    float f0_metal = mat_f0_metal(specularData.g);
    float porosity = mat_porosity(specularData.b, roughness, f0_metal);
    float sss = mat_sss(specularData.b);
    float emission = mat_emission(specularData);
    float occlusion = mat_occlusion(normalData.z);

//    #if MATERIAL_FORMAT == MAT_LABPBR
//        float occlusion = normalData.z;
//    #elif MATERIAL_FORMAT == MAT_OLDPBR
//        float occlusion = 1.0;
//        //float sss = 0.0;
//    #endif

//    #if MATERIAL_FORMAT == MAT_NONE
//        vec3 localTexNormal = localGeoNormal;
//        float occlusion = 1.0;
//        float roughness = 0.92;
//        float f0_metal = 0.0;
//        float porosity = 1.0;
//        float sss = 0.0;
//        float emission = iris_getEmission(vIn.blockId) / 15.0;
//
//        //emission *= lmcoord.x;
//    #endif

    #ifdef RENDER_EMISSIVE
        emission = lmcoord.x * 0.06;
        lmcoord.x = 0.0;
    #endif

    #if MATERIAL_FORMAT != MAT_NONE
        #if defined RENDER_PARALLAX && defined MATERIAL_PARALLAX_SHARP
            if (!skipParallax) {
                float depthDiff = max(texDepth - traceCoordDepth.z, 0.0);

                if (depthDiff >= ParallaxSharpThreshold) {
                    localTexNormal = GetParallaxSlopeNormal(mUV, mLOD, traceCoordDepth.z, tanViewDir);
                }
            }
        #endif

        vec3 localTangent = normalize(vIn.localTangent.xyz);
        mat3 TBN = GetTBN(localGeoNormal, localTangent, vIn.localTangent.w);

        localTexNormal = normalize(TBN * localTexNormal);
    #endif

    #ifdef RENDER_TERRAIN
        bool is_fluid = iris_hasFluid(vIn.blockId);
        uint block_emission = iris_getEmission(vIn.blockId);
    #endif

    #if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
        if (is_fluid) {
            #ifdef WATER_WAVES_ENABLED
                vec3 waveOffset = GetWaveHeight(vIn.surfacePos + ap.camera.pos, lmcoord.y, ap.time.elapsed, WaterWaveOctaveMax);

                vec3 wavePos = vIn.surfacePos;
                wavePos.y += (waveOffset.y) * vIn.waveStrength;

                vec3 dX = normalize(dFdxFine(wavePos));
                vec3 dY = normalize(dFdyFine(wavePos));
                localTexNormal = normalize(cross(dX, dY));
            #endif

            // vec3 localViewDir = normalize(localPos);
            // float NoVm = max(dot(localNormal, -localViewDir), 0.0);
            // float F = F_schlick(NoVm, 0.02, 1.0);

            roughness = 0.02;
            albedo.a = 0.02; //F;
        }
    #endif

    #ifdef RENDER_TRANSLUCENT
        #ifdef RENDER_TERRAIN
            float alphaThreshold = is_fluid ? -1.0 : (0.5/255.0);
        #else
            const float alphaThreshold = (0.5/255.0);
        #endif
    #else
        const float alphaThreshold = 0.1;
    #endif

    //if (iris_discardFragment(albedo)) {discard; return;}
    if (albedo.a < alphaThreshold) {discard; return;}

    albedo *= mColor;

    #ifndef RENDER_TRANSLUCENT
        albedo.a = 1.0;
    #endif

    #if defined(FANCY_LAVA) && defined(RENDER_TERRAIN)
        if (is_fluid && block_emission > 0) {
            vec3 worldPos = ap.camera.pos + vIn.localPos;
            vec3 viewPos = mul3(ap.camera.view, vIn.localPos);
            vec3 viewGeoNormal = mat3(ap.camera.view) * localGeoNormal;

            #if FANCY_LAVA_RES != 0
                worldPos = floor(worldPos * FANCY_LAVA_RES) / FANCY_LAVA_RES;
            #endif

            ApplyLavaMaterial(albedo.rgb, localTexNormal, roughness, emission, viewGeoNormal, worldPos, viewPos);
            localTexNormal = mat3(ap.camera.viewInv) * localTexNormal;
            albedo.a = 1.0;
            f0_metal = 0.07;
            sss = 0.0;
        }
    #endif

    #if LIGHTING_MODE == LIGHT_MODE_VANILLA
        vec3 viewPos = mul3(ap.camera.view, vIn.localPos);
        vec3 viewGeoNormal = mat3(ap.camera.view) * localGeoNormal;
        vec3 viewTexNormal = mat3(ap.camera.view) * localTexNormal;
        ApplyDirectionalLightmap(lmcoord.x, viewPos, viewGeoNormal, viewTexNormal);
    #endif

    outColor = albedo;

    outTexNormal = vec4((localTexNormal * 0.5 + 0.5), 1.0);

    outData.r = packUnorm4x8(vec4((localGeoNormal * 0.5 + 0.5), 0.0));
    outData.g = packUnorm4x8(vec4(roughness, f0_metal, emission, sss));
    outData.b = packUnorm4x8(vec4(lmcoord, occlusion, porosity));
    outData.a = vIn.blockId;
}
