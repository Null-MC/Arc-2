bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 tint, out vec3 hitPos, out vec3 hitNormal, out vec2 hitCoord, out VoxelBlockFace blockFace) {
    vec3 currPos = GetVoxelPosition(localPos);

    vec3 stepSizes, nextDist;
    dda_init(stepSizes, nextDist, currPos, localDir);

    vec3 stepAxis = vec3(0.0); // todo: set initial?
    tint = vec3(1.0);
    bool hit = false;
    ivec3 voxelPos;

    float waterDist = 0.0;

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        vec3 stepAxisNext;
        vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

        voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));
        
        uint blockId = SampleVoxelBlock(voxelPos);

        bool isFullBlock = iris_isFullBlock(blockId);
        if (blockId > 0u && isFullBlock) {
            hit = true;
            break;
        }

        currPos += step;
        stepAxis = stepAxisNext;

        if (blockId > 0) {
            vec3 blockColor = iris_getLightColor(blockId).rgb;
            tint *= RgbToLinear(blockColor);

            if (iris_hasFluid(blockId))
                waterDist += length(step);
        }
    }

    if (waterDist > EPSILON) {
        const vec3 waterExtinction = VL_WaterTransmit + VL_WaterScatter;
        tint *= exp(-waterDist * VL_WaterDensity * waterExtinction);
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
