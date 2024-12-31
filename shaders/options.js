function setupOptions() {
    let screen_Sky = new Page("Sky")
        .add(asInt("SKY_SUN_ANGLE", -20, -10, 0, 10, 20).build(-20))
        .add(asInt("SKY_SEA_LEVEL", -20, -10, 0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120).build(60))
        .build();

    let screen_Water = new Page("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asInt("WATER_TESSELLATION_LEVEL", 2, 4, 6, 8, 10, 12).build(4))
        .build();

    const screen_Shadows = new Page("Shadows")
        .add(asBool("SHADOWS_ENABLED", true))
        .build();

    let screen_Parallax = new Page("Parallax")
        .add(asBool("MATERIAL_PARALLAX_ENABLED", true))
        .add(asBool("MATERIAL_PARALLAX_SHARP", true))
        .add(asInt("MATERIAL_PARALLAX_SAMPLES", 32, 64, 128).build(32))
        .add(asInt("MATERIAL_PARALLAX_DEPTH", 25, 50, 75, 100).build(25))
        .build();

    let screen_Material = new Page("Material")
        .add(asInt("MATERIAL_FORMAT", 0, 1, 2).build(1))
        .add(screen_Parallax)
        .build();

    let screen_RT = new Page("RT Options")
        .add(asInt("RT_MAX_SAMPLE_COUNT", 2, 4, 8, 16, 0).build(8))
        .add(asBool("LIGHTING_TRACE_TRIANGLE", false))
        .build();

    let screen_Lighting = new Page("Lighting")
        .add(asInt("LIGHTING_MODE", 0, 1, 2).build(1))
        .add(asInt("LIGHTING_REFLECT_MODE", 0, 1, 2).build(1))
        .add(asBool("LIGHTING_REFLECT_NOISE", false))
        .add(screen_RT)
        .add(asBool("LPV_RSM_ENABLED", true))
        .build();

    let screen_Voxel = new Page("Voxels")
        .add(asInt("VOXEL_SIZE", 64, 128, 256).build(128))
        .add(asInt("VOXEL_FRUSTUM_OFFSET", 0, 50, 80).build(0))
        .build();

    const screen_Effects = new Page("Effects")
        .add(asBool("EFFECT_SSAO_ENABLED", true))
        .add(asBool("EFFECT_SSGI_ENABLED", false))
        .build();

    const screen_Post = new Page("Post")
        .add(asBool("POST_BLOOM_ENABLED", true))
        .add(asBool("EFFECT_TAA_ENABLED", true))
        .build();

    const screen_Debug = new Page("Debug")
        .add(asBool("DEBUG_ENABLED", false))
        .build();

    return new Page("main")
        .add(screen_Sky, screen_Water)
        .add(screen_Shadows, screen_Material)
        .add(screen_Lighting, screen_Voxel)
        .add(screen_Effects, screen_Post)
        .add(EMPTY, screen_Debug)
        .build();
}
