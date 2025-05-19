#version 430 core

//layout(location = 0) out vec4 outColor;


#ifdef RENDER_GBUFFER
    void iris_emitFragment() {
    //outColor = vec4(0.0);
    }
#else
    void main() {
        //outColor = vec4(0.0);
    }
#endif
