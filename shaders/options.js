function setupOptions() {
    let screen_Sky = new Screen("Sky")
        .add(asString("SKY_SUN_ANGLE", "-20", "-10", "0", "10", "20"))
        .add(asString("SKY_SEA_LEVEL", "60", "0", "10", "20", "30", "40", "50", "60", "70", "80", "90"))
        .build();

    let screen_Water = new Screen("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asString("WATER_TESSELLATION_LEVEL", "2", "4", "6", "8", "10", "12"))
        .build();

    const screen_Shadows = new Screen("Shadows")
        .add(asBool("SHADOWS_ENABLED", true))
        .build();

    let screen_Material = new Screen("Material")
        .add(asString("MATERIAL_FORMAT", "1", "0", "1", "2"))
        .build();

    let screen_Lighting = new Screen("Lighting")
        .add(asString("LIGHTING_MODE", "1", "0", "2"))
        .add(asString("LIGHTING_REFLECT_MODE", "1", "0", "2"))
        .add(asBool("LIGHTING_REFLECT_NOISE", false))
        .add(asBool("LIGHTING_TRACE_TRIANGLE", false))
        .add(asBool("LPV_RSM_ENABLED", true))
        .build();

    let screen_Voxel = new Screen("Voxels")
        .add(asString("VOXEL_SIZE", "128", "64", "128", "256"))
        .add(asString("VOXEL_FRUSTUM_OFFSET", "0", "50", "80"))
        .build();

    const screen_Effects = new Screen("Effects")
        .add(asBool("EFFECT_SSAO_ENABLED", true))
        .add(asBool("EFFECT_SSGI_ENABLED", false))
        .build();

    const screen_Post = new Screen("Post")
        .add(asBool("POST_BLOOM_ENABLED", true))
        .add(asBool("EFFECT_TAA_ENABLED", true))
        .build();

    const screen_Debug = new Screen("Debug")
        .add(asBool("DEBUG_ENABLED", false))
        .build();

    return new Screen("main")
        .add(screen_Sky, screen_Water)
        .add(screen_Shadows, screen_Material)
        .add(screen_Lighting, screen_Voxel)
        .add(screen_Effects, screen_Post)
        .add(EMPTY, screen_Debug)
        .build();
}
