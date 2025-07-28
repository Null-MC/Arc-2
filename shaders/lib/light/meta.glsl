float getLightSize(const in uint blockId) {
    return iris_isFullBlock(blockId) ? 1.0 : 0.15;
}
