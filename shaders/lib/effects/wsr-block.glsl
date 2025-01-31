const int WSR_MAXSTEPS = 64;


bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec3 hitNormal, out vec2 hitCoord, out VoxelBlockFace blockFace) {
    vec3 currPos = GetVoxelPosition(localPos);

    vec3 stepDir = sign(localDir);
    vec3 stepSizes = 1.0 / abs(localDir);
    vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(currPos)) / localDir;

    vec3 stepAxis = vec3(0.0); // todo: set initial?
    bool hit = false;
    ivec3 voxelPos;

    for (int i = 0; i < WSR_MAXSTEPS && !hit; i++) {
        float closestDist = minOf(nextDist);
        vec3 step = localDir * closestDist;

        voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

        uint blockId = imageLoad(imgVoxelBlock, voxelPos).r;
        bool isFullBlock = blockId > 0u && iris_isFullBlock(blockId);

        if (isFullBlock) {
            hitPos = currPos;
            hitNormal = -stepDir * stepAxis;
            hit = true;
        }

        stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;
        currPos += step;
    }

    if (hit) {
        int blockFaceIndex = GetVoxelBlockFaceIndex(hitNormal);
        int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(voxelPos, blockFaceIndex);
        blockFace = VoxelBlockFaceMap[blockFaceMapIndex];

        if (abs(hitNormal.y) > 0.5)      hitCoord = hitPos.xz;
        else if (abs(hitNormal.z) > 0.5) hitCoord = hitPos.xy;
        else                             hitCoord = hitPos.zy;

        hitCoord = 1.0 - fract(hitCoord);
    }

    return hit;
}
