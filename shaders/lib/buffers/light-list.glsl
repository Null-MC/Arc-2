struct PointLight {
    uint voxelIndex;
    #ifdef LIGHTING_MODE == LIGHT_MODE_SHADOWS
        uint shadowIndex;
    #endif
};

struct LightBin {
    uint lightCount;                     // 4
    #ifdef LIGHTING_MODE == LIGHT_MODE_SHADOWS
        uint shadowLightCount;           // 4
    #endif
    PointLight lightList[RT_MAX_LIGHT_COUNT];  // [4|8]*N
};

layout(binding = 3) buffer lightListBuffer {
    uint Scene_LightCount;          // 4
    LightBin LightBinMap[];         // [4|8]*(N + 1)
};
