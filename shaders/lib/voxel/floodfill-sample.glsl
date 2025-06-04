vec3 floodfill_sample(const in vec3 lpvPos) {
    if (!voxel_isInBounds(lpvPos)) return vec3(0.0);

    vec3 texcoord = lpvPos / VoxelBufferSize;
    bool altFrame = ap.time.frames % 2 == 1;

    vec3 color = altFrame
        ? textureLod(texFloodFill_alt, texcoord, 0).rgb
        : textureLod(texFloodFill, texcoord, 0).rgb;

    color = RgbToHsv(color);
    color.z = pow(color.z, 1.25) * 1.0;
    color = HsvToRgb(color);

    return color * BLOCK_LUX;
}
