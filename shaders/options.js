function setupOptions() {
    const screen_Sky = new Page("Sky")
        .add(asIntEx(
            "SKY_SEA_LEVEL", 60,
            -40, 140, 1))
        .add(asIntEx(
            "SKY_SUN_ANGLE", -20,
            -45, +45, 1))
        .add(asIntEx(
            "SKY_FOG_DENSITY", 10,
            0, 100, 1))
        .build();

    let screen_Water = new Page("Water")
        .add(asBool("WATER_WAVES_ENABLED", true))
        .add(asBool("WATER_TESSELLATION_ENABLED", true))
        .add(EMPTY)
        .add(asIntEx(
            "WATER_TESSELLATION_LEVEL", 4,
            2, 12, 1))
        .build();

    const screen_Shadows = new Page("Shadows")
        .add(asBool("SHADOWS_ENABLED", true))
        .build();

    let screen_Parallax = new Page("Parallax")
        .add(asBool("MATERIAL_PARALLAX_ENABLED", true))
        .add(asIntEx(
            "MATERIAL_PARALLAX_SAMPLES", 32,
            8, 128, 8))
        .add(asBool("MATERIAL_PARALLAX_SHARP", true))
        .add(asIntEx(
            "MATERIAL_PARALLAX_DEPTH", 25,
            5, 100, 5))
        .add(asBool("MATERIAL_PARALLAX_DEPTHWRITE", false))
        .build();

    let screen_Material = new Page("Material")
        .add(asInt("MATERIAL_FORMAT", 0, 1, 2).build(1))
        .add(screen_Parallax)
        .build();

    let screen_Reflections = new Page("Reflections")
        .add(asInt("LIGHTING_REFLECT_MODE", 0, 1, 2).build(1))
        .add(asBool("LIGHTING_REFLECT_NOISE", true))
        .add(asBool("LIGHTING_REFLECT_TRIANGLE", false))
        .build();

    let screen_RT = new Page("RT Options")
        .add(asInt("RT_MAX_SAMPLE_COUNT", 2, 4, 8, 12, 16, 20, 24, 28, 32, 48, 64, 0).build(8))
        .add(asBool("LIGHTING_TRACE_TRIANGLE", false))
        .build();

    let screen_Lighting = new Page("Lighting")
        .add(asInt("LIGHTING_MODE", 0, 1, 2).build(1))
        .add(screen_RT)
        .add(asBool("LPV_RSM_ENABLED", true))
        .add(screen_Reflections)
        .build();

    let screen_Voxel = new Page("Voxels")
        .add(asInt("VOXEL_SIZE", 64, 128, 256).build(128))
        .add(asInt("VOXEL_FRUSTUM_OFFSET", 0, 25, 50, 75).build(0))
        .build();

    const screen_Effects = new Page("Effects")
        .add(asBool("EFFECT_SSAO_ENABLED", true))
        .add(asBool("EFFECT_SSGI_ENABLED", false))
        .build();

    const screen_Exposure = new Page("Exposure")
        .add(asFloatEx(
            "POST_EXPOSURE_MIN", -10.5,
            -12.0, -3.0, 0.5))
        .add(asFloatEx(
            "POST_EXPOSURE_MAX", 17.0,
            6.0, 32.0, 0.5))
        .add(asFloatEx(
            "POST_EXPOSURE_SPEED", 0.4,
            0.1, 2.0, 0.1))
        .build();

    const screen_Post = new Page("Post")
        .add(asBool("POST_BLOOM_ENABLED", true))
        .add(screen_Exposure)
        .add(asBool("EFFECT_TAA_ENABLED", true))
        .build();

    const screen_Debug = new Page("Debug")
        .add(asBool("DEBUG_ENABLED", false))
        .add(asInt("DEBUG_VIEW", 0, 1, 2, 3, 4, 5, 6).build(0))
        .add(EMPTY)
        .add(asInt("DEBUG_MATERIAL", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10).build(0))
        .build();

    return new Page("main")
        .add(screen_Sky, screen_Water)
        .add(screen_Shadows, screen_Material)
        .add(screen_Lighting, screen_Voxel)
        .add(screen_Effects, screen_Post)
        .add(EMPTY, screen_Debug)
        .build();
}

function asIntEx(keyName, defaultValue, valueMin, valueMax, interval) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asInt(keyName, ...values).build(defaultValue);
}

function asFloatEx(keyName, defaultValue, valueMin, valueMax, interval) {
    const values = getValueRange(valueMin, valueMax, interval)
        .map(v => v.toFixed(1).toString());

    return asString(keyName, ...values).build(defaultValue.toFixed(1).toString());
}

function getValueRange(valueMin, valueMax, interval) {
    const values = [];

    let value = valueMin;
    while (value <= valueMax) {
        values.push(value);
        value += interval;
    }

    return values;
}