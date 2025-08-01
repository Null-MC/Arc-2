#version 450

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

in VertexData2 {
    vec2 uv;
} vIn;

#include "/lib/common.glsl"


void iris_emitFragment() {
    vec2 mUV = vIn.uv;
    vec2 mLight = vec2(0.0);
    vec4 mColor = vec4(1.0);
    iris_modifyBase(mUV, mColor, mLight);

    mUV *= GLINT_SCALE;

    outColor = vec4(iris_sampleBaseTex(mUV).rgb, 1.0);
}
