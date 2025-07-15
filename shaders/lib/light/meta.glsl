float getLightSize(const in int blockId) {
    return iris_isFullBlock(blockId) ? 1.0 : 0.15;
}
