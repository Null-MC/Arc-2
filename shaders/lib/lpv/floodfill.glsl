vec3 sample_floodfill(const in vec3 lpvPos) {
    if (!IsInVoxelBounds(lpvPos)) return vec3(0.0);

    vec3 texcoord = lpvPos / VoxelBufferSize;
    bool altFrame = ap.time.frames % 2 == 1;

    vec3 color = altFrame
        ? textureLod(texFloodFill_alt, texcoord, 0).rgb
        : textureLod(texFloodFill, texcoord, 0).rgb;

    //color = RgbToLinear(color);

    return color * BLOCKLIGHT_BRIGHTNESS;
}
