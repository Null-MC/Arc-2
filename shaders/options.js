function setupOptions() {
    let screenSky = new Screen("Sky")
        .add(asString("SKY_SUN_ANGLE", "-20", "-10", "0", "10", "20"))
        .build();

    let screenWater = new Screen("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asString("WATER_TESSELLATION_LEVEL", "2", "4", "6", "8", "10", "12"))
        .build();

    return new Screen("main")
        .add(screenSky, screenWater)
        .add(asBool("VL", true), asBool("LPV", false))
        .build();
}
