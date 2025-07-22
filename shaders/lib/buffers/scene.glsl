layout(binding = SSBO_SCENE) buffer sceneBuffer { // 28 +64 +12
    float Scene_AvgExposure;        // 4
    vec3 Scene_SunColor;            // 12
    vec3 Scene_MoonColor;           // 12
    vec3 Scene_LocalSunDir;         // 16
    vec3 Scene_LocalLightDir;       // 16
    vec3 Scene_SkyIrradianceUp;     // 16

    vec3 Scene_TrackPos;            // 16
    float Scene_SkyBrightnessSmooth; // 4
    float Scene_SkyPrecipitation;   // 4
    float Scene_FocusDepth;         // 4
};
