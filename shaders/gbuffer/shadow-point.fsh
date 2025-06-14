#version 430 core

in VertexData2 {
    vec2 uv;
} vIn;


void iris_emitFragment() {
    const float alphaThreshold = 0.2;

    float alpha = iris_sampleBaseTex(vIn.uv).a;
    if (alpha < alphaThreshold) discard;
}
