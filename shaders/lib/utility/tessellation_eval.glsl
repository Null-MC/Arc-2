#define _interpolate(v0, v1, v2) (gl_TessCoord.x * (v0) + gl_TessCoord.y * (v1) + gl_TessCoord.z * (v2))

// #if DISPLACE_MODE == DISPLACE_TESSELATION
//     vec3 GetSampleOffset() {
//         float strength = ParallaxDepthF;

//         #ifdef MATERIAL_TESSELLATION_EDGE_FADE
//             float edge = maxOf(2.0 * abs(vOut.localCoord - 0.5));
//             strength *= smoothstep(1.0, 0.85, edge);
//         #endif

//         float depthSample = texture(normals, vOut.texcoord).a;
//         float offsetDepthSample = MaterialTessellationOffset - depthSample;
//         offsetDepthSample *= step(depthSample, 0.9999);

//         return vOut.localNormal * -(offsetDepthSample * strength);
//     }
// #endif
