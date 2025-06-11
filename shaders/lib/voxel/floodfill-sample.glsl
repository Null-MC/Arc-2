float floodfill_getFade(const in vec3 bufferPos) {
    const float LPV_PADDING = 8.0;

    const vec3 lpvSizeInner = VoxelBufferCenter - LPV_PADDING;

    vec3 viewDir = ap.camera.viewInv[2].xyz;
    vec3 lpvDist = abs(bufferPos - VoxelBufferCenter);
    vec3 lpvDistF = max(lpvDist - lpvSizeInner, vec3(0.0));
    return saturate(1.0 - maxOf((lpvDistF / LPV_PADDING)));
}

vec3 floodfill_sample(const in vec3 lpvPos) {
    if (!voxel_isInBounds(lpvPos)) return vec3(0.0);

    vec3 texcoord = lpvPos / VoxelBufferSize;
    bool altFrame = ap.time.frames % 2 == 1;

    vec3 color = altFrame
        ? textureLod(texFloodFill_alt, texcoord, 0).rgb
        : textureLod(texFloodFill, texcoord, 0).rgb;

//    color = RgbToHsv(color);
//    //if (color.z < 1.0) color.z = pow5(color.z);
//    color = HsvToRgb(color);

    return color * BLOCK_LUX;
}
