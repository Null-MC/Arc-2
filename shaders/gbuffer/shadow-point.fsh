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

out float gl_FragDepth;

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

        vec3 tanViewDir = normalize(vIn.tangentViewPos);

        float depthInitial = iris_sampleNormalMapLod(mUV, int(LOD)).a;

        const float pomViewDist = 0.0;
        vec2 localCoord = GetLocalCoord(mUV, vIn.atlasCoordMin, vIn.atlasCoordSize);
        mUV = GetParallaxCoord(localCoord, LOD, tanViewDir, pomViewDist, texDepth, traceCoordDepth);

        // depth-write
        float pomDist = (1.0 - traceCoordDepth.z) / max(-tanViewDir.z, 0.00001);
        float finalDist = length(vIn.modelPos);

        if (pomDist > 0.0 && depthInitial < 1.0) {
            const float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01;
            finalDist += pomDist * ParallaxDepthF;
        }
    #else
        float finalDist = length(vIn.modelPos);
    #endif
    gl_FragDepth = (finalDist - pointNearPlane) / (pointFarPlane - pointNearPlane);

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
