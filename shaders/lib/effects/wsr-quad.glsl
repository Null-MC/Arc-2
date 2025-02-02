bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec2 hitUV, out vec4 hitColor, out Quad hitQuad) {
    vec4 colorFinal = vec4(0.0);
    vec3 currPos = GetVoxelPosition(localPos) / QUAD_BIN_SIZE;

    vec3 stepSizes, nextDist, stepAxis;
    dda_init(stepSizes, nextDist, currPos, localDir);

    bool hit = false;

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        vec3 step = dda_step(stepAxis, nextDist, stepSizes, localDir);
        vec3 nextPos = currPos + step;

        ivec3 quadBinPos = ivec3(floor(currPos + 0.5*step));
        int quadBinIndex = GetQuadBinIndex(quadBinPos);
        uint quadCount = SceneQuads.bin[quadBinIndex].count;

        vec3 traceStart = (currPos - quadBinPos)*QUAD_BIN_SIZE;
        vec3 traceEnd = (nextPos - quadBinPos)*QUAD_BIN_SIZE;

        float hit_dist = 99999.9;
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
                    hit_dist = sampleDist;

                    hitPos = fma(quadBinPos, vec3(QUAD_BIN_SIZE), hit_pos);
                    hitColor = sampleColor;
                    hitQuad = quad;
                    hitUV = uv;
                    hit = true;
                }
            }
        }

        currPos = nextPos;
    }

    return hit;
}
