#define DDA_MAX_STEP 20

const uint DDAStepCount = uint(DDA_MAX_STEP);


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
                ivec3 quadBinPos = voxelPos;
                int quadBinIndex = GetQuadBinIndex(quadBinPos);
                uint quadCount = SceneQuads.bin[quadBinIndex].count;

                vec3 rayStart = (rayStart - quadBinPos)*QUAD_BIN_SIZE;
                vec3 rayEnd = (currPos - quadBinPos)*QUAD_BIN_SIZE;

                for (int t = 0; t < quadCount && !hit; t++) {
                    Quad quad = SceneQuads.bin[quadBinIndex].quadList[t];

                    vec3 quad_pos_0 = GetQuadVertexPos(quad.pos[0]);
                    vec3 quad_pos_1 = GetQuadVertexPos(quad.pos[1]);
                    vec3 quad_pos_2 = GetQuadVertexPos(quad.pos[2]);

                    vec3 hit_pos;
                    vec2 hit_uv;
                    vec3 rayDir = normalize(rayEnd - rayStart);
                    if (lineQuadIntersect(rayStart, rayDir, quad_pos_0, quad_pos_1, quad_pos_2, hit_pos, hit_uv)) {
                        vec2 uv_min = GetQuadUV(quad.uv_min);
                        vec2 uv_max = GetQuadUV(quad.uv_max);
                        vec2 uv = fma(hit_uv, uv_max - uv_min, uv_min);

                        vec4 sampleColor = vec4(1.0);//textureLod(blockAtlas, uv, 0);
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
                    else {
                        vec3 tintColor = iris_getLightColor(blockId).rgb;
                        color *= RgbToLinear(tintColor);
                    }
                }
            #endif
        }

        currDist2 = lengthSq(currPos - origin);
    }

    if (hit) color = vec3(0.0);
    return color;
}
