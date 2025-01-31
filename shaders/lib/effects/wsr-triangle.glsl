bool TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec2 hitUV, out vec3 hitCoord, out vec4 hitColor, out Triangle hitTriangle) {
    vec4 colorFinal = vec4(0.0);
    vec3 currPos = GetVoxelPosition(localPos) / TRIANGLE_BIN_SIZE;

    vec3 stepDir = sign(localDir);
    vec3 stepSizes = 1.0 / abs(localDir);
    vec3 nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(currPos)) / localDir;

    bool hit = false;

    for (int i = 0; i < LIGHTING_REFLECT_MAXSTEP && !hit; i++) {
        vec3 rayStart = currPos;

        float closestDist = minOf(nextDist);
        currPos = fma(localDir, vec3(closestDist), currPos);

        ivec3 triangleBinPos = ivec3(floor(0.5 * (currPos + rayStart)));

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist = fma(stepSizes, stepAxis, nextDist);

        int triangleBinIndex = GetTriangleBinIndex(triangleBinPos);
        uint triangleCount = TriangleBinMap[triangleBinIndex].triangleCount;

        vec3 traceStart = (rayStart - triangleBinPos)*TRIANGLE_BIN_SIZE;
        vec3 traceEnd = (currPos - triangleBinPos)*TRIANGLE_BIN_SIZE;

        float hit_dist = 999.9;
        for (int t = 0; t < triangleCount; t++) {
            Triangle tri = TriangleBinMap[triangleBinIndex].triangleList[t];

            vec3 tri_pos_0 = GetTriangleVertexPos(tri.pos[0]);
            vec3 tri_pos_1 = GetTriangleVertexPos(tri.pos[1]);
            vec3 tri_pos_2 = GetTriangleVertexPos(tri.pos[2]);

            vec3 coord;
            if (lineTriangleIntersect(traceStart, traceEnd, tri_pos_0, tri_pos_1, tri_pos_2, coord)) {
                vec3 pos = tri_pos_0 * coord.x;
                pos = fma(tri_pos_1, vec3(coord.y), pos);
                pos = fma(tri_pos_2, vec3(coord.z), pos);

                float sampleDist = distance(traceStart, pos);
                if (sampleDist > hit_dist) continue;

                vec2 tri_uv_0 = GetTriangleUV(tri.uv[0]);
                vec2 tri_uv_1 = GetTriangleUV(tri.uv[1]);
                vec2 tri_uv_2 = GetTriangleUV(tri.uv[2]);

                vec2 uv = tri_uv_0 * coord.x;
                uv = fma(tri_uv_1, vec2(coord.y), uv);
                uv = fma(tri_uv_2, vec2(coord.z), uv);

                vec4 sampleColor = textureLod(blockAtlas, uv, 0);

                if (sampleColor.a > 0.5) {
                    hitCoord = coord;
                    hitTriangle = tri;
                    hitColor = sampleColor;

                    hitPos = fma(triangleBinPos, vec3(TRIANGLE_BIN_SIZE), pos);
                    hitUV = uv;
                    hit = true;
                    hit_dist = sampleDist;
                }
            }
        }
    }

    return hit;
}
