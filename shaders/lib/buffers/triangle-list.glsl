struct Triangle {       // 8*4= 32
    f16vec3 pos[3];
};

struct TriangleBin {
    uint triangleCount;                       // 4
    Triangle triangleList[TRIANGLE_BIN_MAX];  // 32*N
};

layout(binding = 4) buffer triangleListBuffer {
    uint Scene_TriangleCount;       // 4
    TriangleBin TriangleBinMap[];
};
