struct LightBin {
    uint lightCount;                     // 4
    uint lightList[RT_MAX_LIGHT_COUNT];  // 4*N
};

layout(binding = 3) buffer lightListBuffer {
    uint Scene_LightCount;          // 4
    LightBin LightBinMap[];
};
