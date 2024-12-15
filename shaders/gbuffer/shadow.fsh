#version 430 core

in vec4 vColor;
in vec2 vUV;

#if defined LPV_ENABLED && defined LPV_RSM_ENABLED
    in vec3 vLocalNormal;
#endif

layout(location = 0) out vec4 outColor;

#if defined LPV_ENABLED && defined LPV_RSM_ENABLED
    layout(location = 1) out vec4 outNormal;
#endif


void iris_emitFragment() {
    outColor = iris_sampleBaseTex(vUV) * vColor;

    if (outColor.a < 0.2) discard;

    #if defined LPV_ENABLED && defined LPV_RSM_ENABLED
        vec3 localNormal = normalize(vLocalNormal);
        outNormal = vec4((localNormal * 0.5 + 0.5), 1.0);
    #endif
}
