#define DDA_MAX_STEP 6 //((LIGHTING_RANGE/100.0) * 24)

const uint DDAStepCount = uint(DDA_MAX_STEP);


bool lineTriangleIntersect(const in vec3 p1, const in vec3 p2, const in vec3 v0, const in vec3 v1, const in vec3 v2, out vec3 coord) {
    vec3 normal = cross(v1 - v0, v2 - v0);
    float d = dot(normal, v0);

    float t = (d - dot(normal, p1)) / dot(normal, p2 - p1);
    if (t < 0.0 || t > 1.0) return false;

    vec3 intersection = p1 + t * (p2 - p1);

    coord = vec3(
        dot(cross(v2 - v1, intersection - v1), normal) / dot(normal, cross(v2 - v1, v0 - v1)),
        dot(cross(v0 - v2, intersection - v2), normal) / dot(normal, cross(v0 - v2, v1 - v2)),
        dot(cross(v1 - v0, intersection - v0), normal) / dot(normal, cross(v1 - v0, v2 - v0))
    );

    return all(greaterThanEqual(coord, vec3(0.0)));
}

vec3 TraceDDA(vec3 origin, const in vec3 endPos, const in float range, const in bool traceSelf) {
    vec3 traceRay = endPos - origin;
    float traceRayLen = length(traceRay);
    if (traceRayLen < EPSILON) return vec3(1.0);

    vec3 direction = traceRay / traceRayLen;

    vec3 stepDir = sign(direction);
    vec3 stepSizes = 1.0 / abs(direction);
    vec3 nextDist = (stepDir * 0.5 + 0.5 - fract(origin)) / direction;

    ivec3 gridCell, blockCell;

    float traceRayLen2 = min(traceRayLen, range);
    traceRayLen2 = traceRayLen2*traceRayLen2;

    vec3 color = vec3(1.0);
    vec3 currPos = origin;
    float currDist2 = 0.0;
    bool hit = false;

    // #if LIGHTING_TINT_MODE == LIGHT_TINT_BASIC
    //     uint blockIdLast;
    // #endif

    if (!traceSelf) {
        float closestDist = minOf(nextDist);
        currPos += direction * closestDist;

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;
    }

    for (int i = 0; i < DDAStepCount; i++) {
        if (hit || currDist2 >= traceRayLen2) break;

        vec3 rayStart = currPos;

        float closestDist = minOf(nextDist);
        currPos += direction * closestDist;

        float currLen2 = lengthSq(currPos - origin);
        if (currLen2 > traceRayLen2) currPos = endPos;
        
        ivec3 voxelPos = ivec3(floor(0.5 * (currPos + rayStart)));

        // if (!traceSelf && ivec3(voxelPos) == ivec3(endPos)) i = 999;

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;

        if (IsInVoxelBounds(voxelPos)) {
            #ifdef RT_TRI_ENABLED
                ivec3 triangleBinPos = voxelPos;// ivec3(floor(voxelPos / TRIANGLE_BIN_SIZE));
                int triangleBinIndex = GetTriangleBinIndex(triangleBinPos);
                uint triangleCount = TriangleBinMap[triangleBinIndex].triangleCount;

                vec3 rayStart = (rayStart - triangleBinPos)*TRIANGLE_BIN_SIZE;
                vec3 rayEnd = (currPos - triangleBinPos)*TRIANGLE_BIN_SIZE;

                for (int t = 0; t < triangleCount && !hit; t++) {
                    Triangle tri = TriangleBinMap[triangleBinIndex].triangleList[t];

                    vec3 coord;
                    if (lineTriangleIntersect(rayStart, rayEnd, tri.pos[0], tri.pos[1], tri.pos[2], coord)) {
                        vec2 uv = tri.uv[0] * coord.x
                                + tri.uv[1] * coord.y
                                + tri.uv[2] * coord.z;

                        vec4 sampleColor = textureLod(blockAtlas, uv, 0);
                        // sampleColor.rgb = RgbToLinear(sampleColor.rgb);

                        //color *= sampleColor.rgb; //mix(sampleColor.rgb, vec3(1.0), (sampleColor.a*sampleColor.a));
                        color = sqrt(color) * sampleColor.rgb;

                        hit = sampleColor.a > 0.9;
                    }
                }
            #else
                uint blockId = imageLoad(imgVoxelBlock, voxelPos).r;

                if (blockId != 0u) {
                    bool isFullBlock = iris_isFullBlock(blockId);
                    if (isFullBlock) hit = true;
                }
            #endif
        }

        currDist2 = lengthSq(currPos - origin);
    }

    if (hit) color = vec3(0.0);
    return color;
}
