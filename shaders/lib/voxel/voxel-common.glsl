const ivec3 VoxelBufferSize = ivec3(VOXEL_SIZE);
const ivec3 VoxelBufferCenter = VoxelBufferSize / 2;
const float VoxelFrustumOffsetF = VOXEL_FRUSTUM_OFFSET * 0.01;

#define BLOCK_FACE_DOWN 0u
#define BLOCK_FACE_UP 1u
#define BLOCK_FACE_NORTH 2u
#define BLOCK_FACE_SOUTH 3u
#define BLOCK_FACE_WEST 4u
#define BLOCK_FACE_EAST 5u


vec3 GetVoxelCenter(const in vec3 viewPos, const in vec3 viewDir) {
    ivec3 offset = ivec3(floor(viewDir * VoxelBufferCenter * VoxelFrustumOffsetF));
    return (VoxelBufferCenter + offset) + fract(viewPos);
}

vec3 voxel_GetBufferPosition(const in vec3 position) {
    return position + GetVoxelCenter(ap.camera.pos, ap.camera.viewInv[2].xyz);
}

vec3 voxel_getLocalPosition(vec3 voxelPos) {
    return voxelPos - GetVoxelCenter(ap.camera.pos, ap.camera.viewInv[2].xyz);
}

bool voxelCustom_isInBounds(const in ivec3 voxelPos) {
    return clamp(voxelPos, 0, VOXEL_SIZE-1) == voxelPos;
}

bool voxel_isInBounds(const in ivec3 voxelPos) {
    #ifdef VOXEL_PROVIDED
        float renderDistSq = _pow2(ap.camera.renderDistance);
        vec3 localPos = voxel_getLocalPosition(voxelPos);
        vec3 worldPos = localPos + ap.camera.pos;

        return worldPos.y > -64 && worldPos.y < 320 && lengthSq(localPos) < renderDistSq;
    #else
        return voxelCustom_isInBounds(voxelPos);
    #endif
}

bool voxel_isInBounds(const in vec3 voxelPos) {
    return voxel_isInBounds(ivec3(voxelPos));
//    #ifdef VOXEL_PROVIDED
//        float renderDistSq = _pow2(ap.camera.renderDistance);
//        vec3 localPos = voxel_getLocalPosition(voxelPos);
//        vec3 worldPos = localPos + ap.camera.pos;
//
//        return worldPos.y > -64 && worldPos.y < 320 && lengthSq(localPos) < renderDistSq;
//    #else
//        return clamp(voxelPos, 0.5, VOXEL_SIZE-0.5) == voxelPos;
//    #endif
}

int voxel_GetBufferIndex(ivec3 voxelPos) {
	const ivec3 flatten = ivec3(1, VOXEL_SIZE, VOXEL_SIZE*VOXEL_SIZE);
	return sumOf(flatten * voxelPos);
}


//#ifdef VOXEL_ENABLED
    bool iris_hasAnyTag(uint blockData, uint tags) {
        return (blockData & tags) != 0u;
    }
//#endif
