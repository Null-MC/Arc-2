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
        .build();

    return new Screen("main")
        .add(screen_Sky, screen_Water, screen_Material)
        .add(asBool("VL", true), asBool("LPV", false))
        .build();
}
