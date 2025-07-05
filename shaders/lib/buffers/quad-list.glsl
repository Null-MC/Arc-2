// lmcoord contains all 4 vertices packed as bits 0-32

struct Quad {       // 24+16= 40
    uvec2 pos[3];   // 8*3=24
    uint lmcoord;   // 4
    uint tint;      // 4
    uint uv_min;    // 4
    uint uv_max;    // 4
};

struct QuadBin {
    uint count;                   // 4
    Quad quadList[QUAD_BIN_MAX];  // 36*N
};

layout(binding = SSBO_QUAD_LIST) buffer QuadListBuffer {
    // TODO: for debug only!
    uint total;       // 4
    QuadBin bin[];
} SceneQuads;

vec3 GetQuadVertexPos(const in uvec2 data) {
    return vec3(
        unpackHalf2x16(data.x),
        unpackHalf2x16(data.y).x
    );
}

uvec2 SetQuadVertexPos(const in vec3 pos) {
    return uvec2(
        packHalf2x16(pos.xy),
        packHalf2x16(pos.zz).x
    );
}

vec2 GetQuadUV(const in uint data) {
    return unpackHalf2x16(data);
}

uint SetQuadUV(const in vec2 pos) {
    return packHalf2x16(pos);
}

void GetQuadLightMapCoord(const in uint data, out vec2 v1, out vec2 v2, out vec2 v3, out vec2 v4) {
    v1.x = bitfieldExtract(data,  0, 4) / 15.0;
    v1.y = bitfieldExtract(data,  4, 4) / 15.0;
    v2.x = bitfieldExtract(data,  8, 4) / 15.0;
    v2.y = bitfieldExtract(data, 12, 4) / 15.0;
    v3.x = bitfieldExtract(data, 16, 4) / 15.0;
    v3.y = bitfieldExtract(data, 20, 4) / 15.0;
    v4.x = bitfieldExtract(data, 24, 4) / 15.0;
    v4.y = bitfieldExtract(data, 28, 4) / 15.0;
}

void SetQuadLightMapCoord(out uint data, const in vec2 v1, const in vec2 v2, const in vec2 v3, const in vec2 v4) {
    data = 0u;
    data = bitfieldInsert(data, uint(v1.x * 15.0),  0, 4);
    data = bitfieldInsert(data, uint(v1.y * 15.0),  4, 4);
    data = bitfieldInsert(data, uint(v2.x * 15.0),  8, 4);
    data = bitfieldInsert(data, uint(v2.y * 15.0), 12, 4);
    data = bitfieldInsert(data, uint(v3.x * 15.0), 16, 4);
    data = bitfieldInsert(data, uint(v3.y * 15.0), 20, 4);
    data = bitfieldInsert(data, uint(v4.x * 15.0), 24, 4);
    data = bitfieldInsert(data, uint(v4.y * 15.0), 28, 4);
}
