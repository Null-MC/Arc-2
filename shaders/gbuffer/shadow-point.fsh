#version 430 core

in VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;
} vIn;


void iris_emitFragment() {
    const float alphaThreshold = 0.2;

    float alpha = iris_sampleBaseTex(vIn.uv).a;
    if (alpha < alphaThreshold) discard;

    if (vIn.isFull) {
        if (clamp(vIn.modelPos, -0.5, 0.5) == vIn.modelPos) {
            discard;
        }
    }
    else {
        if (length(vIn.modelPos) < 0.2) discard;
    }
}
