import type {} from './iris'

export function setupOptions() {
    const screen_Sky = new Page("Sky")
        .add(asIntRange("SKY_SEA_LEVEL", 60, -40, 140, 2, false))
        .add(asIntRange("SKY_SUN_ANGLE", -20, -90, 90, 2, false))
        .add(asIntRange("SKY_FOG_DENSITY", 8, 0, 100, 1, false))
        .add(asBool("SKY_CLOUDS_ENABLED", false, true))
        .add(asBool("SKY_FOG_NOISE", false, true))
        .build();

    let screen_Water = new Page("Water")
        .add(asBool("WATER_WAVES_ENABLED", true, true))
        .add(asIntRange("WATER_WAVES_DETAIL", 14, 2, 32, 1, false))
        .add(asBool("WATER_TESSELLATION_ENABLED", true, true))
        .add(asIntRange("WATER_TESSELLATION_LEVEL", 4, 2, 12, 1, false))
        .build();

    const screen_Shadows = new Page("Shadows")
        .add(asBool("SHADOWS_ENABLED", true, true))
        .add(asBool("SHADOWS_CLOUD_ENABLED", true, true))
        .add(asInt("SHADOW_RESOLUTION", 256, 512, 1024, 2048, 4096).build(1024))
        .build();

    let screen_Parallax = new Page("Parallax")
        .add(asBool("MATERIAL_PARALLAX_ENABLED", true, true))
        .add(asIntRange("MATERIAL_PARALLAX_SAMPLES", 32, 8, 128, 8))
        .add(asBool("MATERIAL_PARALLAX_SHARP", true, true))
        .add(asIntRange("MATERIAL_PARALLAX_DEPTH", 25, 5, 100, 5))
        .add(asBool("MATERIAL_PARALLAX_DEPTHWRITE", false, true))
        .build();

    let screen_Material = new Page("Material")
        .add(asInt("MATERIAL_FORMAT", 0, 1, 2).build(1))
        .add(screen_Parallax)
        .add(asIntRange("EMISSION_BRIGHTNESS", 160, 0, 800, 10))
        .add(asBool("FANCY_LAVA", true, true))
        .add(EMPTY)
        .add(asInt("FANCY_LAVA_RES", 4, 8, 16, 32, 64, 128, 0).build(0))
        .build();

    let screen_Lighting = new Page("Lighting")
        .add(asInt("LIGHTING_MODE", 0, 1, 2).build(1))
        .add(new Page("RT Options")
            .add(asInt("RT_MAX_SAMPLE_COUNT", 2, 4, 8, 12, 16, 20, 24, 28, 32, 48, 64, 0).build(16))
            .add(asBool("LIGHTING_TRACE_TRIANGLE", false, true))
            .build())
        .add(asBool("LPV_RSM_ENABLED", false, true))
        .add(new Page("Reflections")
            .add(asInt("LIGHTING_REFLECT_MODE", 0, 1, 2).build(2))
            .add(asBool("LIGHTING_REFLECT_TRIANGLE", false, true))
            .add(asBool("LIGHTING_REFLECT_NOISE", true, true))
            .add(asIntRange("LIGHTING_REFLECT_MAXSTEP", 64, 8, 256, 8))
            .build())
        .add(asInt("LIGHTING_VL_RES", 0, 1, 2).build(1))
        .build();

    let screen_Voxel = new Page("Voxels")
        .add(asInt("VOXEL_SIZE", 64, 128, 256).build(128))
        .add(asInt("VOXEL_FRUSTUM_OFFSET", 0, 25, 50, 75).build(0))
        .build();

    const screen_Effects = new Page("Effects")
        .add(new Page("SSGI/SSAO")
            .add(asBool("EFFECT_SSAO_ENABLED", true, true))
            .add(asBool("EFFECT_SSGI_ENABLED", false, true))
            .add(asIntRange("EFFECT_SSGIAO_SAMPLES", 12, 1, 64, 1))
            .build())
        .add(new Page("Bloom")
            .add(asBool("EFFECT_BLOOM_ENABLED", true, true))
            .add(asFloatRange("EFFECT_BLOOM_STRENGTH", 2.5, 0.0, 20.0, 0.1, false))
            .build())
        .build();

    const screen_Post = new Page("Post")
        .add(asBool("EFFECT_TAA_ENABLED", true, true))
        .add(new Page("Exposure")
            .add(asFloatRange("POST_EXPOSURE_MIN", -10.5, -12.0, -3.0, 0.5, false))
            .add(asFloatRange("POST_EXPOSURE_MAX", 15.0, 6.0, 32.0, 0.5, false))
            .add(asFloatRange("POST_EXPOSURE_SPEED", 1.2, 0.1, 2.0, 0.1, false))
            .build())
        .add(asIntRange("POST_CONTRAST", 160,0, 300, 5, false))
        .build();

    const screen_Debug = new Page("Debug")
        .add(asBool("DEBUG_ENABLED", false, true))
        .add(asInt("DEBUG_VIEW", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10).needsReload(true).build(0))
        .add(asBool("DEBUG_WHITE_WORLD", false, true))
        .add(asInt("DEBUG_MATERIAL", 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10).needsReload(true).build(0))
        .build();

    return new Page("main")
        .add(screen_Sky, screen_Water)
        .add(screen_Shadows, screen_Material)
        .add(screen_Lighting, screen_Voxel)
        .add(screen_Effects, screen_Post)
        .add(EMPTY, screen_Debug)
        .build();
}

function asIntRange(keyName: String, defaultValue: Number, valueMin: Number, valueMax: Number, interval: Number, reload: Boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval);
    return asInt(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asFloatRange(keyName: String, defaultValue: Number, valueMin: Number, valueMax: Number, interval: Number, reload: Boolean = true) {
    const values = getValueRange(valueMin, valueMax, interval)
        .map(v => v.toFixed(1).toString());

    return asString(keyName, ...values).needsReload(reload)
        .build(defaultValue.toFixed(1).toString());
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
