#version 430 core

in VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;
} vIn;


void iris_emitFragment() {
    float alpha = iris_sampleBaseTex(vIn.uv).a;

    if (vIn.isFull) {
        if (clamp(vIn.modelPos, -0.5, 0.5) == vIn.modelPos) alpha = 0.0;
    }
    else {
        if (length(vIn.modelPos) < 0.2) alpha = 0.0;
    }

    const float alphaThreshold = 0.2;
    if (alpha < alphaThreshold) discard;
}
