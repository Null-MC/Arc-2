#ifdef VOXEL_WRITE
    layout(r32ui) uniform writeonly uimage3D imgVoxelBlock;
#else
    layout(r32ui) uniform readonly uimage3D imgVoxelBlock;
#endif

#ifdef VOXEL_BLOCK_FACE
    struct VoxelBlockFace {     // 12
        uint tex_id;
        uint tint;
        uint lmcoord; // todo: any way to make this smaller?
    };

    layout(binding = 5) buffer voxelBlockTexBuffer {
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

    void GetBlockFaceLightMap(const in uint data, out vec2 lmcoord) {
        lmcoord.x = bitfieldExtract(data,  0, 4) / 15.0;
        lmcoord.y = bitfieldExtract(data,  4, 4) / 15.0;
    }

    void SetBlockFaceLightMap(const in vec2 lmcoord, out uint data) {
        data = 0u;
        data = bitfieldInsert(data, uint(lmcoord.x * 15.0),  0, 4);
        data = bitfieldInsert(data, uint(lmcoord.y * 15.0),  4, 4);
    }
#endif
