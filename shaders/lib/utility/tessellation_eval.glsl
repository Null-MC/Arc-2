//#define _interpolate(v0, v1, v2) (gl_TessCoord.x * (v0) + gl_TessCoord.y * (v1) + gl_TessCoord.z * (v2))

#define _interpolate(v, p) (gl_TessCoord.x * v[0].p + gl_TessCoord.y * v[1].p + gl_TessCoord.z * v[2].p)
