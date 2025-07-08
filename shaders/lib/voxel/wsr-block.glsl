bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 tint, out vec3 hitPos, out vec3 hitNormal, out vec2 hitCoord, out VoxelBlockFace blockFace) {
    vec3 currPos = voxel_GetBufferPosition(localPos);
    ivec3 voxelPos = ivec3(floor(currPos));

    vec3 stepAxis = vec3(0.0); // todo: set initial?
    tint = vec3(1.0);
    bool hit = false;

    float waterDist = 0.0;

    vec3 voxel_offset = GetVoxelCenter(ap.camera.pos, ap.camera.viewInv[2].xyz);

    vec3 stepSizes, nextDist;
    dda_init(stepSizes, nextDist, currPos, localDir);

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        #ifdef VOXEL_SKIP_EMPTY
            #ifdef VOXEL_SKIP_SECTIONS
                vec3 ap_blockPos = voxelPos - voxel_offset + ap.camera.pos;
                ivec3 ap_voxelPos = ivec3(floor(ap_blockPos));
                bool isSectionLoaded = iris_isSectionLoaded(ap_voxelPos);

                if (!isSectionLoaded) {
                    tint *= vec3(1.0, 0.5, 0.5);

                    vec3 section_pos = ap_blockPos / 16.0;
                    section_pos.y += ap.world.internal_chunkDiameter.z;

                    vec3 section_stepSizes, section_nextDist;
                    dda_init(section_stepSizes, section_nextDist, section_pos, localDir);

                    vec3 section_stepAxisNext;
                    vec3 section_step = dda_step(section_stepAxisNext, section_nextDist, section_stepSizes, localDir);

                    section_pos += section_step;
                    //section_stepAxis = section_stepAxisNext;

                    section_pos.y -= ap.world.internal_chunkDiameter.z;
                    ap_blockPos = section_pos * 16.0;
                    currPos = ap_blockPos + voxel_offset - ap.camera.pos;

                    dda_init(stepSizes, nextDist, currPos, localDir);
                }

                vec3 stepAxisNext;
                vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

                voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

                uint blockId = SampleVoxelBlock(voxelPos);
            #else
                vec3 stepAxisNext;
                vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

                voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

                uint blockId = SampleVoxelBlock(voxelPos);

                for (int t = 0; t < 8 && blockId == 0u; t++) {
                    currPos += step;
                    stepAxis = stepAxisNext;

                    step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

                    voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

                    blockId = SampleVoxelBlock(voxelPos);
                }
            #endif
        #else
            vec3 stepAxisNext;
            vec3 step = dda_step(stepAxisNext, nextDist, stepSizes, localDir);

            voxelPos = ivec3(floor(fma(step, vec3(0.5), currPos)));

            uint blockId = SampleVoxelBlock(voxelPos);
        #endif

        if (!voxel_isInBounds(voxelPos)) break;

        if (blockId > 0u) {
            if (iris_isFullBlock(blockId)) hit = true;

            uint blockTags = iris_blockInfo.blocks[blockId].z;
            const uint make_solid_tags = (1u << TAG_LEAVES) | (1u << TAG_STAIRS) | (1u << TAG_SLABS);
            if (iris_hasAnyTag(blockTags, make_solid_tags)) hit = true;

            if (hit) break;
        }

        currPos += step;
        stepAxis = stepAxisNext;

        if (blockId > 0) {
            if (iris_hasTag(blockId, TAG_TINTS_LIGHT)) {
                vec3 blockTint = iris_getLightColor(blockId).rgb;
                tint *= RgbToLinear(blockTint);
            }
            else if (iris_hasFluid(blockId))
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

        if (voxelCustom_isInBounds(voxelPos)) {
            int blockFaceIndex = GetVoxelBlockFaceIndex(hitNormal);
            int blockFaceMapIndex = GetVoxelBlockFaceMapIndex(voxelPos, blockFaceIndex);
            blockFace = VoxelBlockFaceMap[blockFaceMapIndex];
        }
        else {
            blockFace = EmptyBlockFace;
        }

        if (abs(hitNormal.y) > 0.5)      hitCoord = hitPos.xz;
        else if (abs(hitNormal.z) > 0.5) hitCoord = hitPos.xy;
        else                             hitCoord = hitPos.zy;

        hitCoord = 1.0 - fract(hitCoord);
    }

    return hit;
}
