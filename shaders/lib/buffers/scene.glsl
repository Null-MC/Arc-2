layout(binding = 0) buffer sceneBuffer { // 256 +64 +64 +12
    mat4 shadowProjectionInv[4];    // 64*4=256
    mat4 shadowModelViewInv;        // 64

    float Scene_AvgExposure;        // 4
    vec3 Scene_LocalSunDir;         // 16
    vec3 Scene_LocalLightDir;       // 16
    vec3 Scene_SkyIrradianceUp;     // 16

    vec3 Scene_TrackPos;            // 16
    float Scene_SkyBrightnessSmooth; // 4
    float Scene_FocusDepth;         // 4
};
