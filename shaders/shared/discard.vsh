#version 430 core

#ifdef RENDER_GBUFFER
    void iris_emitVertex(inout VertexData data) {
        data.clipPos = vec4(-10.0);
    }

    void iris_sendParameters(in VertexData data) {}
#else
    void main() {
        gl_Position = vec4(-10.0);
    }
#endif
