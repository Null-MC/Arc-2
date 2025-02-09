#version 430

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

    #if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT) && defined(WATER_TESSELLATION_ENABLED)
        vec3 surfacePos;
        float waveStrength;
    #endif

    #ifdef RENDER_PARALLAX
        vec3 tangentViewPos;
        flat vec2 atlasMinCoord;
        flat vec2 atlasMaxCoord;
    #endif
} vIn;

#include "/lib/common.glsl"

#include "/lib/utility/tbn.glsl"

#include "/lib/material/material.glsl"

#ifdef RENDER_PARALLAX
    #include "/lib/utility/atlas.glsl"

    #include "/lib/material/parallax.glsl"
#endif

#if LIGHTING_MODE == LIGHT_MODE_VANILLA
    #include "/lib/light/lightmap.glsl"
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

    mat2 dFdXY = mat2(dFdx(mUV), dFdy(mUV));

    #ifdef RENDER_PARALLAX
        float texDepth = 1.0;
        vec3 traceCoordDepth = vec3(1.0);

        float viewDist = length(vIn.localPos);
        vec3 tanViewDir = normalize(vIn.tangentViewPos);
        bool skipParallax = false;

        if (!skipParallax && viewDist < MATERIAL_PARALLAX_MAXDIST) {
            vec2 localCoord = GetLocalCoord(mUV, vIn.atlasMinCoord, vIn.atlasMaxCoord);
            mUV = GetParallaxCoord(localCoord, dFdXY, tanViewDir, viewDist, texDepth, traceCoordDepth);

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

    vec4 albedo = iris_sampleBaseTexGrad(mUV, dFdXY[0], dFdXY[1]);

    #if MATERIAL_FORMAT != MAT_NONE
        vec4 normalData = iris_sampleNormalMapGrad(mUV, dFdXY[0], dFdXY[1]);
        vec4 specularData = iris_sampleSpecularMapGrad(mUV, dFdXY[0], dFdXY[1]);
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
        float emission = iris_getEmission(vIn.blockId) / 15.0;
        float porosity = 0.0;
        float sss = 0.0;

        emission *= lmcoord.x;
    #endif

    #if MATERIAL_FORMAT != MAT_NONE
        #if defined RENDER_PARALLAX && defined MATERIAL_PARALLAX_SHARP
            if (!skipParallax) {
                float depthDiff = max(texDepth - traceCoordDepth.z, 0.0);

                if (depthDiff >= ParallaxSharpThreshold) {
                    localTexNormal = GetParallaxSlopeNormal(mUV, dFdXY, traceCoordDepth.z, tanViewDir);
                }
            }
        #endif

        mat3 TBN = GetTBN(localGeoNormal, vIn.localTangent.xyz, vIn.localTangent.w);
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

                // mUV += 0.1*waveOffset.xz;

                vec3 wavePos = vIn.surfacePos;
                wavePos.y += (waveOffset.y - vIn.localOffset.y) * vIn.waveStrength;

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

    #ifndef RENDER_TRANSLUCENT
        albedo.a = 1.0;
    #endif

    #if defined(FANCY_LAVA) && defined(RENDER_TERRAIN)
        if (is_fluid && block_emission > 0) {
            vec3 worldPos = ap.camera.pos + vIn.localPos;
            vec3 viewPos = mul3(ap.camera.view, vIn.localPos);
            vec3 viewGeoNormal = mat3(ap.camera.view) * localGeoNormal;

            worldPos = floor(worldPos * 16.0) / 16.0;

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
    outData.b = packUnorm4x8(vec4(lmcoord, occlusion, 0.0));
    outData.a = vIn.blockId;
}
