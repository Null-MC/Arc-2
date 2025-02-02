#define DDA_MAX_STEP 20

const uint DDAStepCount = uint(DDA_MAX_STEP);


vec3 TraceDDA(vec3 origin, const in vec3 endPos, const in float range, const in bool traceSelf) {
    vec3 traceRay = endPos - origin;
    float traceRayLen = length(traceRay);
    if (traceRayLen < EPSILON) return vec3(1.0);

    vec3 direction = traceRay / traceRayLen;

    vec3 stepSizes, nextDist, stepAxis;
    dda_init(stepSizes, nextDist, origin, direction);

    ivec3 gridCell, blockCell;

    float traceRayLen2 = min(traceRayLen, range);
    traceRayLen2 = traceRayLen2*traceRayLen2;

    vec3 color = vec3(1.0);
    vec3 currPos = origin;
    float currDist2 = 0.0;
    bool hit = false;

    if (!traceSelf) {
        currPos += dda_step(stepAxis, nextDist, stepSizes, direction);
    }

    for (int i = 0; i < DDAStepCount; i++) {
        if (hit || currDist2 >= traceRayLen2) break;

        vec3 rayStart = currPos;

        vec3 step = dda_step(stepAxis, nextDist, stepSizes, direction);
        currPos += step;

        float currLen2 = lengthSq(currPos - origin);
        if (currLen2 > traceRayLen2) currPos = endPos;
        
        ivec3 voxelPos = ivec3(floor(0.5 * (currPos + rayStart)));

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

                    float quadDist = QuadIntersectDistance(rayStart, direction, quad_pos_0, quad_pos_1, quad_pos_2);

                    // TODO: add max-distance check!
                    if (quadDist > -0.0001 && quadDist*quadDist < traceRayLen2) {
                        vec3 hit_pos = direction * quadDist + rayStart;

                        vec2 hit_uv = QuadIntersectUV(hit_pos, quad_pos_0, quad_pos_1, quad_pos_2);

                        if (clamp(hit_uv, 0.0, 1.0) == hit_uv) {
                            vec2 uv_min = GetQuadUV(quad.uv_min);
                            vec2 uv_max = GetQuadUV(quad.uv_max);
                            vec2 uv = fma(hit_uv, uv_max - uv_min, uv_min);

                            vec4 sampleColor = textureLod(blockAtlas, uv, 0);
                            // sampleColor.rgb = RgbToLinear(sampleColor.rgb);

                            //color *= sampleColor.rgb; //mix(sampleColor.rgb, vec3(1.0), (sampleColor.a*sampleColor.a));
                            color = sqrt(color) * sampleColor.rgb;

                            hit = sampleColor.a > 0.9;
                        }
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
