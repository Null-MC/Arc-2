#version 450

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

in VertexData2 {
    vec2 uv;
//    vec4 color;
} vIn;

#include "/lib/common.glsl"


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vec2(0.0);
    vec4 mColor = vec4(1.0);//vIn.color;
    iris_modifyBase(mUV, mColor, mLight);

    vec4 albedo = iris_sampleBaseTex(mUV);

    const float alphaThreshold = 0.1;
    if (albedo.a < alphaThreshold) {discard; return;}

    //albedo *= mColor;
    //albedo.a = 1.0;

    outColor = albedo;
}
