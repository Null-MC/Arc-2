const ivec3 VoxelBufferSize = ivec3(VOXEL_SIZE);
const ivec3 VoxelBufferCenter = VoxelBufferSize / 2;
const float VoxelFrustumOffsetF = VOXEL_FRUSTUM_OFFSET * 0.01;


vec3 GetVoxelCenter(const in vec3 viewPos, const in vec3 viewDir) {
    ivec3 offset = ivec3(floor(viewDir * VoxelBufferCenter * VoxelFrustumOffsetF));
    return (VoxelBufferCenter + offset) + fract(viewPos);
}

vec3 GetVoxelPosition(const in vec3 position) {
    vec3 viewDir = playerModelViewInverse[2].xyz;
    return position + GetVoxelCenter(cameraPos, viewDir);
}

bool IsInVoxelBounds(const in ivec3 voxelPos) {
    return clamp(voxelPos, 0, VOXEL_SIZE-1) == voxelPos;
}

bool IsInVoxelBounds(const in vec3 voxelPos) {
    return clamp(voxelPos, 0.5, VOXEL_SIZE-0.5) == voxelPos;
}
