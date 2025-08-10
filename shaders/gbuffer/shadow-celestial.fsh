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
    #if defined(RENDER_TERRAIN) && defined(RENDER_TRANSLUCENT)
        bool isFluid = iris_hasFluid(vIn.blockId);

        if (isFluid) {
            outColor = vec4(1.0, 1.0, 1.0, 0.02);
            //discard;
        }
        else {
            outColor = iris_sampleBaseTex(vIn.uv) * vIn.color;

            const float alphaThreshold = (1.5/255.0);
            if (outColor.a < alphaThreshold) discard;
            //outColor.rgb = vec3(1,0,0);
        }
    #else
        const float alphaThreshold = 0.2;

        outColor = iris_sampleBaseTex(vIn.uv) * vIn.color;
        if (outColor.a < alphaThreshold) discard;
    #endif

    outColor.a = 1.0;
}
