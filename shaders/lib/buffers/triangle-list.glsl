struct Triangle {       // 12*3+4+4= 44
    f16vec3 pos[3];     // 8
    f16vec2 uv[3];      // 4
    uint lmcoord;
    uint tint;
};

struct TriangleBin {
    uint triangleCount;                       // 4
    Triangle triangleList[TRIANGLE_BIN_MAX];  // 36*N
};

layout(binding = 4) buffer triangleListBuffer {
    uint Scene_TriangleCount;       // 4
    TriangleBin TriangleBinMap[];
};

vec3 GetTriangleVertexPos(const in f16vec3 data) {
    return vec3(data);
}

f16vec3 SetTriangleVertexPos(const in vec3 pos) {
    return f16vec3(pos);
}

void GetTriangleLightMapCoord(const in uint data, out vec2 v1, out vec2 v2, out vec2 v3) {
    v1.x = bitfieldExtract(data,  0, 4) / 15.0;
    v1.y = bitfieldExtract(data,  4, 4) / 15.0;
    v2.x = bitfieldExtract(data,  8, 4) / 15.0;
    v2.y = bitfieldExtract(data, 12, 4) / 15.0;
    v3.x = bitfieldExtract(data, 16, 4) / 15.0;
    v3.y = bitfieldExtract(data, 20, 4) / 15.0;
}

uint SetTriangleLightMapCoord(const in vec2 v1, const in vec2 v2, const in vec2 v3) {
    uint data = 0u;
    data = bitfieldInsert(data, uint(v1.x * 15.0),  0, 4);
    data = bitfieldInsert(data, uint(v1.y * 15.0),  4, 4);
    data = bitfieldInsert(data, uint(v2.x * 15.0),  8, 4);
    data = bitfieldInsert(data, uint(v2.y * 15.0), 12, 4);
    data = bitfieldInsert(data, uint(v3.x * 15.0), 16, 4);
    data = bitfieldInsert(data, uint(v3.y * 15.0), 20, 4);
    return data;
}

//vec3 GetTriangleVertexPos(const in uint pos) {
//    return unpackUnorm4x8(pos).xyz;
//}
//
//uint SetTriangleVertexPos(const in vec3 pos) {
//    return packUnorm4x8(vec4(pos, 0.0));
//}
