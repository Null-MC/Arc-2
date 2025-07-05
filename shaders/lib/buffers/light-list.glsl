#if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
    #define LIGHT_LIST_MAX LIGHTING_SHADOW_BIN_MAX_COUNT
#elif LIGHTING_MODE == LIGHT_MODE_RT
    #define LIGHT_LIST_MAX RT_MAX_LIGHT_COUNT
#else
    //#error "invalid state!"
    #define LIGHT_LIST_MAX 1
#endif


struct PointLight {
    uint voxelIndex;
    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
        uint shadowIndex;
    #endif
};

struct LightBin {
    uint lightCount;                     // 4
    #if LIGHTING_MODE == LIGHT_MODE_SHADOWS && defined(LIGHTING_SHADOW_BIN_ENABLED)
        uint shadowLightCount;           // 4
    #endif
    PointLight lightList[LIGHT_LIST_MAX];  // [4|8]*N
};

layout(binding = SSBO_LIGHT_LIST) buffer lightListBuffer {
    uint Scene_LightCount;          // 4
    LightBin LightBinMap[];         // [4|8]*(N + 1)
};
