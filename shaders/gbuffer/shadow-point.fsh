#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

in VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;
} vIn;

#include "/lib/common.glsl"
#include "/lib/material/material.glsl"


void iris_emitFragment() {
    float LOD = textureQueryLod(irisInt_BaseTex, vIn.uv).y;
    float alpha = iris_sampleBaseTexLod(vIn.uv, LOD).a;
    vec4 specularData = iris_sampleSpecularMapLod(vIn.uv, LOD);

    float emission = mat_emission(specularData);
    if (emission > 0.0) alpha = 0.0;

//    if (vIn.isFull) {
//        if (clamp(vIn.modelPos, -0.5, 0.5) == vIn.modelPos) alpha = 0.0;
//    }
//    else {
//        if (length(vIn.modelPos) < 0.1) alpha = 0.0;
//    }

    const float alphaThreshold = 0.2;
    if (alpha < alphaThreshold) discard;
}
