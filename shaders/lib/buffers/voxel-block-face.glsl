struct VoxelBlockFace {     // 8
    uint tex_id;
    uint data;
};

#ifdef RENDER_SHADOW
    #define VOXEL_BLOCK_FACE_LAYOUT writeonly
#else
    #define VOXEL_BLOCK_FACE_LAYOUT readonly
#endif

layout(std430, binding = SSBO_BLOCK_FACE) VOXEL_BLOCK_FACE_LAYOUT buffer voxelBlockTexBuffer {
    VoxelBlockFace VoxelBlockFaceMap[];
};

int GetVoxelBlockFaceIndex(const in vec3 normal) {
    //return 0;

    if (abs(normal.y) > 0.5) {
        return normal.y > 0.0 ? 0 : 1;
    }
    else if (abs(normal.z) > 0.5) {
        return normal.z > 0.0 ? 2 : 3;
    }
    else {
        return normal.x > 0.0 ? 4 : 5;
    }
}

int GetVoxelBlockFaceMapIndex(const in ivec3 voxelPos, const in int faceIndex) {
    const ivec3 flatten = ivec3(1, VOXEL_SIZE, VOXEL_SIZE*VOXEL_SIZE);
    return 6 * sumOf(flatten * voxelPos) + faceIndex;
}

vec3 GetBlockFaceTint(const in uint data) {
    //return vec3(1.0);
    return unpackUnorm4x8(data).rgb;
}

void SetBlockFaceTint(inout uint data, const in vec3 tint) {
    uint color = packUnorm4x8(vec4(tint, 1.0));
    data = bitfieldInsert(data, color, 0, 24);
}

vec2 GetBlockFaceLightMap(const in uint data) {
    return vec2(
        bitfieldExtract(data, 24, 4),
        bitfieldExtract(data, 28, 4)
    ) / 15.0;
}

void SetBlockFaceLightMap(inout uint data, const in vec2 lmcoord) {
    data = bitfieldInsert(data, uint(lmcoord.x * 15.0), 24, 4);
    data = bitfieldInsert(data, uint(lmcoord.y * 15.0), 28, 4);
}
