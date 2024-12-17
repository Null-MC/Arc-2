function setupOptions() {
    let screenWater = new Screen("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asString("WATER_TESSELLATION_LEVEL", "2", "4", "6", "8", "10", "12"))
        .build();

    return new Screen("main")
        .add(screenWater)
        .add(asBool("VL", true), asBool("LPV", false))
        .build();
}
