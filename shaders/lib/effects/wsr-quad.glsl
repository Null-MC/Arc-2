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
        uint quadCount = min(SceneQuads.bin[quadBinIndex].count, QUAD_BIN_MAX);

        vec3 traceStart = (currPos - quadBinPos)*QUAD_BIN_SIZE;
        vec3 traceEnd = (nextPos - quadBinPos)*QUAD_BIN_SIZE;

        float hit_dist = 99999.9;
        for (int t = 0; t < quadCount; t++) {
            Quad quad = SceneQuads.bin[quadBinIndex].quadList[t];

            vec3 quad_pos_0 = GetQuadVertexPos(quad.pos[0]);
            vec3 quad_pos_1 = GetQuadVertexPos(quad.pos[1]);
            vec3 quad_pos_2 = GetQuadVertexPos(quad.pos[2]);

            float quadDist = QuadIntersectDistance(traceStart, localDir, quad_pos_0, quad_pos_1, quad_pos_2);

            // TODO: add max-distance check!
            if (quadDist > -0.0001 && quadDist < hit_dist) {
                vec3 hit_pos = localDir * quadDist + traceStart;

                vec2 hit_uv = QuadIntersectUV(hit_pos, quad_pos_0, quad_pos_1, quad_pos_2);

                if (clamp(hit_uv, 0.0, 1.0) == hit_uv) {
                    vec2 uv;
                    vec4 sampleColor;
                    if (quad.uv_max != 0u) {
                        vec2 uv_min = GetQuadUV(quad.uv_min);
                        vec2 uv_max = GetQuadUV(quad.uv_max);
                        uv = fma(hit_uv, uv_max - uv_min, uv_min);

                        sampleColor = textureLod(blockAtlas, uv, 0);
                    }
                    else {
                        sampleColor = vec4(1u);//unpackUnorm4x8(quad.uv_min);
                        uv = vec2(0.0);
                    }

                    if (sampleColor.a > 0.5) {
                        hit_dist = quadDist;

                        hitPos = fma(quadBinPos, vec3(QUAD_BIN_SIZE), hit_pos);
                        hitColor = sampleColor;
                        hitQuad = quad;
                        hitUV = uv;
                        hit = true;
                    }
                }
            }
        }

        currPos = nextPos;
    }

    return hit;
}
