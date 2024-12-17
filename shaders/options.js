function setupOptions() {
    let screen_Sky = new Screen("Sky")
        .add(asString("SKY_SUN_ANGLE", "-20", "-10", "0", "10", "20"))
        .build();

    let screen_Water = new Screen("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asString("WATER_TESSELLATION_LEVEL", "2", "4", "6", "8", "10", "12"))
        .build();

    let screen_Material = new Screen("Material")
        .add(asString("MATERIAL_FORMAT", "0", "1", "2"))
        .add(asBool("MATERIAL_SSR_ENABLED", true))
        .build();

    let screen_Voxel_LPV = new Screen("LPV")
        .add(asBool("LPV_ENABLED", true))
        .add(asBool("LPV_RSM_ENABLED", true))
        .build();

    let screen_Voxel = new Screen("Voxels")
        .add(asString("VOXEL_SIZE", "64", "128", "256", "512"))
        .add(screen_Voxel_LPV)
        .build();

    const screen_Post = new Screen("Post")
        .add(asBool("POST_BLOOM_ENABLED", true))
        .add(asBool("EFFECT_TAA_ENABLED", true))
        .build();

    return new Screen("main")
        .add(screen_Sky, screen_Water, screen_Material, screen_Voxel, screen_Post)
        .build();
}
