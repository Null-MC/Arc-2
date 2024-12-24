struct LightBin {
    uint lightCount;                // 4
    uint lightList[LIGHT_BIN_MAX];  // 4*N
};

layout(binding = 3) buffer lightListBuffer {
    uint Scene_LightCount;          // 4
    LightBin LightBinMap[];
};
