#version 430 core

in VertexData2 {
    vec4 color;
    vec2 uv;

    #if defined LPV_ENABLED && defined LPV_RSM_ENABLED
        vec3 localNormal;
    #endif
} vIn;

layout(location = 0) out vec4 outColor;

#if defined LPV_ENABLED && defined LPV_RSM_ENABLED
    layout(location = 1) out vec4 outNormal;
#endif


void iris_emitFragment() {
    outColor = iris_sampleBaseTex(vIn.uv) * vIn.color;

    if (outColor.a < 0.2) discard;

    #if defined LPV_ENABLED && defined LPV_RSM_ENABLED
        vec3 localNormal = normalize(vIn.localNormal);
        outNormal = vec4((localNormal * 0.5 + 0.5), 1.0);
    #endif
}
