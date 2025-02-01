bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec2 hitUV, out vec4 hitColor, out Quad hitQuad) {
    vec4 colorFinal = vec4(0.0);
    vec3 currPos = GetVoxelPosition(localPos) / QUAD_BIN_SIZE;

    vec3 stepDir = sign(localDir);
    vec3 stepSizes = 1.0 / abs(localDir);
    vec3 nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(currPos)) / localDir;

    bool hit = false;

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        vec3 rayStart = currPos;

        float closestDist = minOf(nextDist);
        currPos = fma(localDir, vec3(closestDist), currPos);

        ivec3 quadBinPos = ivec3(floor(0.5 * (currPos + rayStart)));

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist = fma(stepSizes, stepAxis, nextDist);

        int quadBinIndex = GetQuadBinIndex(quadBinPos);
        uint quadCount = SceneQuads.bin[quadBinIndex].count;

        vec3 traceStart = (rayStart - quadBinPos)*QUAD_BIN_SIZE;
        vec3 traceEnd = (currPos - quadBinPos)*QUAD_BIN_SIZE;

        float hit_dist = 999.9;
        for (int t = 0; t < quadCount; t++) {
            Quad quad = SceneQuads.bin[quadBinIndex].quadList[t];

            vec3 quad_pos_0 = GetQuadVertexPos(quad.pos[0]);
            vec3 quad_pos_1 = GetQuadVertexPos(quad.pos[1]);
            vec3 quad_pos_2 = GetQuadVertexPos(quad.pos[2]);

            vec3 hit_pos;
            vec2 hit_uv;
            //vec3 rayDir = normalize(traceEnd - traceStart);
            if (lineQuadIntersect(traceStart, localDir, quad_pos_0, quad_pos_1, quad_pos_2, hit_pos, hit_uv)) {
                float sampleDist = distance(traceStart, hit_pos);
                if (sampleDist > hit_dist) continue;

                vec2 uv_min = GetQuadUV(quad.uv_min);
                vec2 uv_max = GetQuadUV(quad.uv_max);
                vec2 uv = fma(hit_uv, uv_max - uv_min, uv_min);

                vec4 sampleColor = textureLod(blockAtlas, uv, 0);

                if (sampleColor.a > 0.5) {
                    //hitCoord = hit_uv;
                    hitQuad = quad;
                    hitColor = sampleColor;

                    hit_dist = sampleDist;
                    hitPos = fma(quadBinPos, vec3(QUAD_BIN_SIZE), hit_pos);
                    hitUV = uv;
                    hit = true;
                }
            }
        }
    }

    return hit;
}
