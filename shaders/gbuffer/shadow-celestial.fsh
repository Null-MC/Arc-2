#version 430 core

in VertexData2 {
    vec4 color;
    vec2 uv;

    #ifdef RENDER_TERRAIN
        flat uint blockId;
    #endif
} vIn;

layout(location = 0) out vec4 outColor;


void iris_emitFragment() {
    const float alphaThreshold = 0.2;

    #if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
        bool isFluid = iris_hasFluid(vIn.blockId);

        if (isFluid) {
            outColor = vec4(1.0, 1.0, 1.0, 0.02);
            //discard;
        }
        else {
            outColor = iris_sampleBaseTex(vIn.uv) * vIn.color;
            if (outColor.a < alphaThreshold) discard;
        }
    #else
        outColor = iris_sampleBaseTex(vIn.uv) * vIn.color;
        if (outColor.a < alphaThreshold) discard;
    #endif
}
