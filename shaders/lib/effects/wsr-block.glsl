bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec3 hitNormal, out vec2 hitCoord, out VoxelBlockFace blockFace) {
    vec3 currPos = GetVoxelPosition(localPos);

    vec3 stepSizes, nextDist;
    dda_init(stepSizes, nextDist, currPos, localDir);

    vec3 stepAxis = vec3(0.0); // todo: set initial?
    bool hit = false;
    ivec3 voxelPos;

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        vec3 stepAxisNext;
        vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

        voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

        uint blockId = imageLoad(imgVoxelBlock, voxelPos).r;
        bool isFullBlock = blockId > 0u && iris_isFullBlock(blockId);

        if (isFullBlock) {
            hit = true;
        }
        else {
            currPos += step;
            stepAxis = stepAxisNext;
        }
    }

    if (hit) {
        hitPos = currPos;
        hitNormal = -sign(localDir) * stepAxis;

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
