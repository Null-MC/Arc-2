struct Triangle {       // 12*3= 36
    f16vec3 pos[3];     // 8
    f16vec2 uv[3];      // 4
};

struct TriangleBin {
    uint triangleCount;                       // 4
    Triangle triangleList[TRIANGLE_BIN_MAX];  // 36*N
};

layout(binding = 4) buffer triangleListBuffer {
    uint Scene_TriangleCount;       // 4
    TriangleBin TriangleBinMap[];
};
