const int WSR_MAXSTEPS = 24;


vec4 TraceReflection(const in vec3 localPos, const in vec3 localDir, out vec3 hitPos, out vec3 hitNormal, out vec2 hitUV, out vec2 lmcoord, out vec3 tint) {
    vec4 colorFinal = vec4(0.0);
    vec3 currPos = GetVoxelPosition(localPos);// / TRIANGLE_BIN_SIZE;

    vec3 stepDir = sign(localDir);
    vec3 stepSizes = 1.0 / abs(localDir);
    vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(currPos)) / localDir;

    bool hit = false;

    for (int i = 0; i < WSR_MAXSTEPS && !hit; i++) {
        vec3 rayStart = currPos;

        float closestDist = minOf(nextDist);
        currPos += localDir * closestDist;

        ivec3 voxelPos = ivec3(floor(0.5 * (currPos + rayStart)));

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;

        // TODO: hit test
//        ivec3 triangleBinPos = voxelPos;// ivec3(floor(voxelPos / TRIANGLE_BIN_SIZE));
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
                vec3 pos = tri_pos_0 * coord.x
                    + tri_pos_1 * coord.y
                    + tri_pos_2 * coord.z;

                float sampleDist = distance(traceStart, pos);
                if (sampleDist > hit_dist) continue;

                vec2 uv = tri.uv[0] * coord.x
                    + tri.uv[1] * coord.y
                    + tri.uv[2] * coord.z;

                vec4 sampleColor = textureLod(blockAtlas, uv, 0);

                if (sampleColor.a > 0.5) {
                    hitCoord = coord;
                    hitTriangle = tri;
                    hitColor = sampleColor;


//                    colorFinal = sampleColor;
                    hitPos = pos + triangleBinPos*TRIANGLE_BIN_SIZE;
                    hitUV = uv;
                    hit = true;
                    hit_dist = sampleDist;
//                    tint = unpackUnorm4x8(tri.tint).rgb;
//                    lmcoord = tri.lmcoord;

//                    vec3 e1 = normalize(tri_pos_1 - tri_pos_0);
//                    vec3 e2 = normalize(tri_pos_2 - tri_pos_0);
//                    hitNormal = normalize(cross(e1, e2));
                }
            }
        }
    }

//    return colorFinal;
    return hit;
}
