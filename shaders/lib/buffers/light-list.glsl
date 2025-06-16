struct PointLight {
    uint voxelIndex;
    #ifdef LIGHTING_MODE == LIGHT_MODE_SHADOWS
        uint shadowIndex;
    #endif
};


#if LIGHTING_MODE == LIGHT_MODE_SHADOWS
    #define LIGHT_LIST_MAX LIGHTING_SHADOW_MAX_COUNT
#elif LIGHTING_MODE == LIGHT_MODE_RT
    #define LIGHT_LIST_MAX RT_MAX_LIGHT_COUNT
#else
    #error "invalid state!"
#endif

struct LightBin {
    uint lightCount;                     // 4
    #ifdef LIGHTING_MODE == LIGHT_MODE_SHADOWS
        uint shadowLightCount;           // 4
    #endif
    PointLight lightList[LIGHT_LIST_MAX];  // [4|8]*N
};

layout(binding = 3) buffer lightListBuffer {
    uint Scene_LightCount;          // 4
    LightBin LightBinMap[];         // [4|8]*(N + 1)
};
