#define DDA_MAX_STEP 24 //((LIGHTING_RANGE/100.0) * 24)

const uint DDAStepCount = uint(DDA_MAX_STEP);


// bool BoxRayTest(const in vec3 boxMin, const in vec3 boxMax, const in vec3 rayStart, const in vec3 rayInv) {
//     vec3 t1 = (boxMin - rayStart) * rayInv;
//     vec3 t2 = (boxMax - rayStart) * rayInv;

//     vec3 tmin = min(t1, t2);
//     vec3 tmax = max(t1, t2);

//     float rmin = maxOf(tmin);
//     float rmax = minOf(tmax);

//     return !isinf(rmin) && min(rmax, 1.0) >= max(rmin, 0.0);
// }

// bool TraceHitTest(const in uint blockId, const in vec3 rayStart, const in vec3 rayInv) {
//     BlockCollisionData blockData = StaticBlockMap[blockId].Collisions;

//     bool hit = false;
//     for (uint i = 0u; i < BLOCK_MASK_PARTS; i++) {
//         if (hit || i >= blockData.Count) break;

//         vec3 boundsMin = unpackUnorm4x8(blockData.Bounds[i].x).xyz;
//         vec3 boundsMax = unpackUnorm4x8(blockData.Bounds[i].y).xyz;

//         hit = BoxRayTest(boundsMin, boundsMax, rayStart, rayInv);
//     }

//     return hit;
// }

bool lineTriangleIntersect(vec3 p1, vec3 p2, vec3 v0, vec3 v1, vec3 v2) {
    vec3 normal = cross(v1 - v0, v2 - v0);
    float d = dot(normal, v0);

    float t = (d - dot(normal, p1)) / dot(normal, p2 - p1);
    if (t < 0.0 || t > 1.0) return false;

    vec3 intersection = p1 + t * (p2 - p1);

    vec3 bary = vec3(
        dot(cross(v2 - v1, intersection - v1), normal) / dot(normal, cross(v2 - v1, v0 - v1)),
        dot(cross(v0 - v2, intersection - v2), normal) / dot(normal, cross(v0 - v2, v1 - v2)),
        dot(cross(v1 - v0, intersection - v0), normal) / dot(normal, cross(v1 - v0, v2 - v0))
    );

    return (bary.x >= 0.0 && bary.y >= 0.0 && bary.z >= 0.0);
}

bool rayTriangleIntersection(const in vec3 orig, const in vec3 dir,
    const in vec3 v0, const in vec3 v1, const in vec3 v2,
    out vec3 tuv)
{
    vec3 v0v1 = v1 - v0;
    vec3 v0v2 = v2 - v0;
    vec3 pvec = cross(dir, v0v2);
    float det = dot(v0v1, pvec);

    // If det is close to 0, the ray and triangle are parallel.
    if (abs(det) < EPSILON) return false;

    float invDet = 1.0 / det;

    vec3 tvec = orig - v0;
    tuv.y = dot(tvec, pvec) * invDet;
    if (tuv.y < 0.0 || tuv.y > 1.0) return false;

    vec3 qvec = cross(tvec, v0v1);
    tuv.z = dot(dir, qvec) * invDet;
    if (tuv.z < 0.0 || tuv.y + tuv.z > 1.0) return false;
    
    tuv.x = dot(v0v2, qvec) * invDet;
    
    return true;
}

bool rayTriangleIntersection(vec3 ray, vec3 rayDir, vec3 A, vec3 B, vec3 C) { 
    vec3 normal = normalize(cross(B-A, C-A));

    float t = dot(-ray, normal) / dot(normal, rayDir);
    vec3 Q = ray + rayDir*t;
      
    float areaABC = 1.0 / dot(cross(B-A, C-A), normal);     
    float areaQBC = dot(cross(B-A, Q-A), normal);
    float areaAQC = dot(cross(C-B, Q-B), normal);
    float areaABQ = dot(cross(A-C, Q-C), normal);
    
    return areaQBC >= 0.0 && areaAQC >= 0.0 && areaABQ >= 0.0;
}

// bool rayTriangleIntersection(vec3 start, vec3 dir, vec3 a, vec3 b, vec3 c, out vec3 baryCoord) {
//     vec3 d = dir;
//     vec3 t = start - a;
//     vec3 e1 = b - a;
//     vec3 e2 = c - a;
//     vec3 p = cross(d, e2);
//     vec3 q = cross(t, e1);
//     float det = dot(p, e1);

//     // negative det = backface
//     // if (det < 0.0)
//     //   return false;

//     // zero det = coplanar
//     if (abs(det) < 1e-6)
//       return false;

//     vec2 bary2 = vec2(dot(p, t), dot(q, d)) / det;
//     // hitTime = dot(q, e2) / det;

//     baryCoord = vec3(1.0 - bary2.x - bary2.y, bary2);

//     return !any(lessThan(baryCoord, vec3(0.0))) && !any(greaterThan(baryCoord, vec3(1.0)));
// }

// bool rayTriangleIntersection(
//     vec3 ray,
//     vec3 rayDir,
//     vec3 A,
//     vec3 B,
//     vec3 C,
//     out vec3 res) 
// {
//     /* Calculate edges. */
//     vec3 BA = B - A;
//     vec3 CA = C - A;

//     vec3 RDIRcrossCA = cross(rayDir,CA);
    
//     /* Calculate determinant using triple product dot(BA, cross(rayDit, CA)) */
//     float det = dot(BA,RDIRcrossCA);

//     /* Avoiding division by zero. */
//     if (det > -0.00001 && det < 0.00001) { return false; }

//     float invDet = 1.0 / det;
    
//     vec3 RA = ray - A; // distance from ray origin to A vertex of triangle
    
//     float baryU = invDet * dot(RA, RDIRcrossCA);

//     /* Checking edge CA */
//     if (baryU < 0.0 || baryU > 1.0) { return false; }

//     vec3 RAcrossBA = cross(RA,BA);
//     float baryV = invDet * dot(rayDir, RAcrossBA);

//     /* Checking edge BA */
//     if (baryV < 0.0 || baryU + baryV > 1.0) { return false; }

//     // at this stage we can compute t to find out where
//     // the intersection point is on the line
//     float dist = invDet * dot(CA, RAcrossBA);

//     if (dist > 0.00001) // ray intersection
//     {
//         res = vec3(baryU, baryV, dist);
//         return true;
//     }

//     // this means that there is a line intersection
//     // but not a ray intersection
//     return false;       
// }

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
        
        vec3 voxelPos = floor(0.5 * (currPos + rayStart));

        if (!traceSelf && ivec3(voxelPos) == ivec3(endPos)) i = 999;

        vec3 stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

        nextDist -= closestDist;
        nextDist += stepSizes * stepAxis;

        if (IsInVoxelBounds(voxelPos)) {
            uint blockId = imageLoad(imgVoxelBlock, ivec3(voxelPos)).r;



            // #if LIGHTING_TINT_MODE == LIGHT_TINT_ABSORB
            //     if (blockId >= BLOCK_HONEY && blockId <= BLOCK_TINTED_GLASS) {
            //         vec3 glassTint = GetLightGlassTint(blockId);
            //         color *= exp(-2.0 * Lighting_TintF * closestDist * (1.0 - glassTint));
            //     }
            //     else {
            // #elif LIGHTING_TINT_MODE == LIGHT_TINT_BASIC
            //     if (blockId >= BLOCK_HONEY && blockId <= BLOCK_TINTED_GLASS && blockId != blockIdLast) {
            //         vec3 glassTint = GetLightGlassTint(blockId) * Lighting_TintF;
            //         glassTint += max(1.0 - Lighting_TintF, 0.0);

            //         color *= glassTint;
            //     }
            //     else {
            // #endif

            if (blockId != 0u) {
                bool isFullBlock = iris_isFullBlock(blockId);

                if (isFullBlock) hit = true;
                #ifdef RT_TRI_ENABLED
                    else {
                        ivec3 triangleBinPos = ivec3(floor(voxelPos / TRIANGLE_BIN_SIZE));
                        int triangleBinIndex = GetTriangleBinIndex(triangleBinPos);
                        uint triangleCount = TriangleBinMap[triangleBinIndex].triangleCount;

                        vec3 rayStart = rayStart - triangleBinPos*TRIANGLE_BIN_SIZE;
                        vec3 rayEnd = currPos - triangleBinPos*TRIANGLE_BIN_SIZE;

                        for (int t = 0; t < triangleCount; t++) {
                            Triangle tri = TriangleBinMap[triangleBinIndex].triangleList[t];

                            vec3 baryCoord;
                            if (lineTriangleIntersect(rayStart, rayEnd, tri.pos[0], tri.pos[1], tri.pos[2])) {
                                hit = true;
                                break;
                            }
                        }
                    }
                #endif
            }

            // #if LIGHTING_TINT_MODE != LIGHT_TINT_NONE
            //     }
            // #endif

            // #if LIGHTING_TINT_MODE == LIGHT_TINT_BASIC
            //     blockIdLast = blockId;
            // #endif
        }

        currDist2 = lengthSq(currPos - origin);
    }

    if (hit) color = vec3(0.0);
    return color;
}
