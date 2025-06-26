#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

in VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;

    #ifdef IS_POINT_LIGHT_POM_ENABLED
        vec3 shadowViewPos;
        vec3 tangentViewPos;
        flat vec2 atlasCoordMin;
        flat vec2 atlasCoordSize;
    #endif
} vIn;

#ifdef IS_POINT_LIGHT_POM_ENABLED
    layout (depth_greater) out float gl_FragDepth;
#endif

#include "/lib/common.glsl"

#include "/lib/material/material.glsl"

#ifdef IS_POINT_LIGHT_POM_ENABLED
    #include "/lib/sampling/atlas.glsl"
    #include "/lib/sampling/linear.glsl"

    #include "/lib/material/parallax.glsl"
#endif


void iris_emitFragment() {
    vec2 mLight;
    vec4 mColor;
    vec2 mUV = vIn.uv;
    iris_modifyBase(mUV, mColor, mLight);

    float LOD = textureQueryLod(irisInt_BaseTex, mUV).y;

    #ifdef IS_POINT_LIGHT_POM_ENABLED
        float texDepth = 1.0;
        vec3 traceCoordDepth = vec3(1.0);

        float viewDist = 0.0;//length(vIn.localPos);
        vec3 tanViewDir = normalize(vIn.tangentViewPos);
        //bool skipParallax = false;

        float depthInitial = iris_sampleNormalMapLod(mUV, int(LOD)).a;

        vec2 localCoord = GetLocalCoord(mUV, vIn.atlasCoordMin, vIn.atlasCoordSize);
        mUV = GetParallaxCoord(localCoord, LOD, tanViewDir, viewDist, texDepth, traceCoordDepth);

        // depth-write
        float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);

        if (pomDist > 0.0 && depthInitial < 1.0) {
            const float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01;

            vec3 shadowViewPos = vIn.shadowViewPos;
            vec3 viewDir = normalize(shadowViewPos);

            shadowViewPos += viewDir * pomDist * ParallaxDepthF;
//            shadowViewPos.z += pomDist * ParallaxDepthF;
            vec3 ndcPos = unproject(ap.point.projection, shadowViewPos);
            //gl_FragDepth = (((pointFarPlane - pointNearPlane) * ndcPos.z) + pointNearPlane + pointFarPlane) / 2.0;
            gl_FragDepth = ndcPos.z * 0.5 + 0.5;

//            float linearDepth = -vIn.shadowViewPos.z + pomDist * ParallaxDepthF;
//            float ndcDepth = (-ap.point.projection[2].z*linearDepth + ap.point.projection[3].z) / linearDepth;
//            //float ndcDepth = (pointFarPlane + pointNearPlane - 2.0 * pointNearPlane * pointFarPlane / linearDepth) / (pointFarPlane - pointNearPlane);
//            gl_FragDepth = ndcDepth * 0.5 + 0.5;
        }
        else {
            gl_FragDepth = gl_FragCoord.z;
        }
    #endif

    float alpha = iris_sampleBaseTexLod(mUV, LOD).a;

    #ifdef LIGHTING_SHADOW_EMISSION_MASK
        if (clamp(vIn.modelPos, -0.5, 0.5) == vIn.modelPos) {
            vec4 specularData = iris_sampleSpecularMapLod(vIn.uv, LOD);
            float emission = mat_emission(specularData);
            if (emission > 0.0) alpha = 0.0;
        }
    #else
        float near = vIn.isFull ? 0.5 : 0.49999;
        if (clamp(vIn.modelPos, -near, near) == vIn.modelPos) alpha = 0.0;
    #endif

    const float alphaThreshold = 0.2;
    if (alpha < alphaThreshold) discard;
}
