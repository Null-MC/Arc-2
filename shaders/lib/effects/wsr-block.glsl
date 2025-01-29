const int WSR_MAXSTEPS = 48;


bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec3 hitNormal, out VoxelBlockFace blockFace) {
    vec4 colorFinal = vec4(0.0);
    vec3 currPos = GetVoxelPosition(localPos);

    vec3 stepDir = sign(localDir);
    vec3 stepSizes = 1.0 / abs(localDir);
    vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(currPos)) / localDir;

    bool hit = false;
    ivec3 voxelPos;
    uint blockId;

    for (int i = 0; i < WSR_MAXSTEPS && !hit; i++) {
        vec3 rayStart = currPos;

        float closestDist = minOf(nextDist);
        currPos += localDir * closestDist;

        voxelPos = ivec3(floor(0.5 * (currPos + rayStart)));

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;

        blockId = imageLoad(imgVoxelBlock, voxelPos).r;
        bool isFullBlock = blockId > 0u && iris_isFullBlock(blockId);

        if (isFullBlock) {
            hitPos = rayStart;
            hitNormal = stepAxis;
            hit = true;
        }
    }

    if (hit) {
        int blockFaceIndex = GetVoxelBlockFaceIndex(hitNormal);
        int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(voxelPos, blockFaceIndex);
        blockFace = VoxelBlockFaceMap[blockFaceMapIndex];
    }

    return hit;
}
