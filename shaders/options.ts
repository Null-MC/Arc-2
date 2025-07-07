import type {} from './iris'

export function setupOptions() {
    const screen_Sky = new Page("SKY")
        .add(asIntRange("SKY_SUN_TEMP", 5800, 2500, 9000, 100, false))
        .add(asIntRange("SKY_SEA_LEVEL", 60, -40, 140, 2, false))
        .add(asIntRange("SKY_SUN_ANGLE", -20, -90, 90, 2, false))
        .add(EMPTY)
        .add(new Page('SKY_WIND')
            .add(asBool('SKY_WIND_ENABLED', true, true))
            .build())
        .add(new Page("SKY_FOG")
            .add(asIntRange("SKY_FOG_DENSITY", 16, 0, 100, 1, false))
            .add(asBool("SKY_FOG_NOISE", false, true))
            .add(EMPTY)
            .add(asBool("FOG_CAVE_ENABLED", true, true))
            .build())
        .add(new Page("SKY_CLOUDS")
            .add(asBool("SKY_CLOUDS_ENABLED", true, true))
            .add(asIntRange("SKY_CLOUD_COVERAGE", 50, 0, 100, 2, false))
            .build())
        .build();

    let screen_Water = new Page("WATER")
        .add(asBool("WATER_WAVES_ENABLED", true, true))
        .add(asIntRange("WATER_WAVES_DETAIL", 9, 2, 32, 1, false))
        .add(asFloatRange("WATER_WAVES_HEIGHT", 0.25, 0.0, 1.0, 0.05, false))
        .add(EMPTY)
        .add(asBool("WATER_TESSELLATION_ENABLED", true, true))
        .add(asIntRange("WATER_TESSELLATION_LEVEL", 4, 2, 12, 1, false))
        .build();

    const screen_Shadows = new Page("SHADOWS")
        .add(asBool("SHADOWS_ENABLED", true, true))
        .add(asBool("SHADOW_PCSS_ENABLED", true, true))
        .add(asIntRange("SHADOW_DISTANCE", 200, 50, 2000, 50, true))
        .add(asInt("SHADOW_RESOLUTION", 256, 512, 1024, 2048, 4096).build(1024))
        .add(asIntRange("SHADOW_CASCADE_COUNT", 4, 1, 6, 1, true))
        .add(asBool("SHADOWS_SS_FALLBACK", true, true))
        .add(asBool("SHADOWS_CLOUD_ENABLED", true, true))
        .build();

    let screen_Material = new Page('MATERIAL')
        .add(asString('MATERIAL_FORMAT', '0', '1', '2').build('1'))
        .add(EMPTY)
        .add(new Page('MATERIAL_PARALLAX')
            .add(asBool('MATERIAL_PARALLAX_ENABLED', true, true))
            .add(asIntRange('MATERIAL_PARALLAX_SAMPLES', 32, 8, 128, 8))
            // .add(asBool('MATERIAL_PARALLAX_SHARP', true, true))
            .add(asString('MATERIAL_PARALLAX_TYPE', '0', '1', '2').build('1'))
            .add(asIntRange('MATERIAL_PARALLAX_DEPTH', 25, 5, 100, 5))
            .add(asBool('MATERIAL_PARALLAX_DEPTHWRITE', false, true))
            .build())
        .add(new Page('MATERIAL_NORMALS')
            .add(asString('MATERIAL_NORMAL_FORMAT', '-1', '0', '1', '2').build('-1'))
            .add(asBool('MATERIAL_NORMAL_SMOOTH', false, true))
            .build())
        .add(new Page('MATERIAL_POROSITY')
            .add(asString('MATERIAL_POROSITY_FORMAT', '-1', '0', '1', '2').build('-1'))
            .build())
        .add(new Page('MATERIAL_EMISSION')
            .add(asString('MATERIAL_EMISSION_FORMAT', '-1', '0', '1', '2').build('-1'))
            .add(asIntRange('MATERIAL_EMISSION_BRIGHTNESS', 160, 0, 800, 5, false))
            .build())
        .add(new Page('MATERIAL_SSS')
            .add(asString('MATERIAL_SSS_FORMAT', '-1', '0', '1').build('-1'))
            .add(asFloatRange('MATERIAL_SSS_DISTANCE', 3.0, 0.1, 6.0, 0.1, true))
            .add(asFloatRange('MATERIAL_SSS_RADIUS', 0.5, 0.1, 1.0, 0.05, true))
            .build())
        .add(EMPTY)
        .add(asBool("FANCY_LAVA", true, true))
        .add(asInt("FANCY_LAVA_RES", 4, 8, 16, 32, 64, 128, 0).build(0))
        .build();

    let screen_Lighting = new Page('LIGHTING')
        .add(asString('LIGHTING_MODE', '0', '1', '2', '3').build('1'))
        .add(new Page('LIGHTING_GI')
            .add(asBool("LIGHTING_GI_ENABLED", false, true))
            .add(asBool("LIGHTING_GI_SKYLIGHT", true, true))
            .add(asInt("LIGHTING_GI_CASCADES", 1, 2, 3, 4).build(3))
            .add(asInt("LIGHTING_GI_SIZE", 32, 64, 128).build(64))
            .add(asInt("VOXEL_GI_MAXFRAMES", 4, 8, 16, 32, 48, 64, 96, 128).build(32))
            .add(asIntRange("VOXEL_GI_MAXSTEP", 8, 2, 32, 2, true))
            .add(asInt("WSGI_SCALE_BASE", 0, 1, 2).build(0))
            .build())
        .add(EMPTY)
        .add(new Page("LIGHTING_REFLECTIONS")
            .add(asString("LIGHTING_REFLECT_MODE", '0', '1', '2').build('2'))
            .add(asBool("LIGHTING_REFLECT_TRIANGLE", false, true))
            .add(asBool("LIGHTING_REFLECT_NOISE", true, true))
            .add(asIntRange("LIGHTING_REFLECT_MAXSTEP", 16, 4, 128, 4))
            .build())
        .add(new Page('LIGHTING_RT')
            .add(asInt('RT_MAX_SAMPLE_COUNT', 2, 4, 8, 12, 16, 20, 24, 28, 32, 48, 64, 0).build(16))
            .add(asIntRange('RT_MAX_LIGHT_COUNT', 64, 4, 256, 4, true))
            .add(asIntRange('LIGHT_TRACE_PENUMBRA', 100, 0, 100, 2, false))
            .add(asBool('LIGHTING_TRACE_TRIANGLE', false, true))
            .build())
        .add(new Page('LIGHTING_SHADOWS')
            .add(asInt('LIGHTING_SHADOW_RESOLUTION', 32, 64, 128, 256, 512).needsReload(true).build(128))
            .add(asIntRange('LIGHTING_SHADOW_RANGE', 100, 10, 400, 10, true))
            .add(asBool('LIGHTING_SHADOW_PCSS', false, true))
            .add(asBool('LIGHTING_SHADOW_EMISSION_MASK', false, true))
            .add(asBool('LIGHTING_SHADOW_BIN_ENABLED', true, true))
            .add(asIntRange('LIGHTING_SHADOW_BIN_MAX_COUNT', 64, 2, 128, 2, true))
            .add(EMPTY)
            .add(asIntRange('LIGHTING_SHADOW_MAX_COUNT', 64, 2, 256, 2, true))
            .add(asIntRange('LIGHTING_SHADOW_REALTIME', 2, 0, 64, 1, false))
            .add(asIntRange('LIGHTING_SHADOW_UPDATES', 1, 1, 16, 1, false))
            .add(asIntRange('LIGHTING_SHADOW_UPDATE_THRESHOLD', 10, 1, 99, 1, false))
            .build())
        .add(new Page('LIGHTING_VOLUMETRIC')
            .add(asInt('LIGHTING_VL_RES', 0, 1, 2).build(1))
            .add(asBool('LIGHTING_VL_SHADOWS', false, true))
            .build())
        .add(asIntRange('BLOCKLIGHT_TEMP', 3400, 1000, 8500, 100, false))
        .add(asBool('LIGHTING_COLOR_CANDLES', false, true))
        .build();

    let screen_Voxel = new Page("VOXELS")
        .add(asInt("VOXEL_SIZE", 64, 128, 256).build(128))
        .add(asInt("VOXEL_FRUSTUM_OFFSET", 0, 25, 50, 75).build(0))
        .add(asBool("VOXEL_PROVIDED", true, true))
        .build();

    const screen_Effects = new Page("EFFECTS")
        .add(new Page("EFFECT_SSAO")
            .add(asBool("EFFECT_SSAO_ENABLED", true, true))
            .add(asIntRange("EFFECT_SSAO_STRENGTH", 140, 5, 200, 5, false))
            .add(asIntRange("EFFECT_SSAO_SAMPLES", 4, 1, 16, 1))
            .build())
        .add(new Page("EFFECT_BLOOM")
            .add(asBool("EFFECT_BLOOM_ENABLED", true, true))
            .add(asFloatRange("EFFECT_BLOOM_STRENGTH", 2.0, 0.0, 10.0, 0.05, false))
            .build())
        .add(new Page("EFFECT_DOF")
            .add(asBool("EFFECT_DOF_ENABLED", true, true))
            .add(asIntRange("EFFECT_DOF_SAMPLES", 16, 4, 32, 4, true))
            .add(asIntRange("EFFECT_DOF_RADIUS", 6, 1, 20, 1, false))
            .add(asIntRange("EFFECT_DOF_SPEED", 20, 1, 40, 1, true))
            .build())
        .build();

    const screen_Post = new Page("POST")
        .add(asBool("EFFECT_TAA_ENABLED", true, true))
        .add(new Page("POST_EXPOSURE")
            .add(asFloatRange("POST_EXPOSURE_MIN", -5.0, -8.0, 1.0, 0.5, false))
            .add(asFloatRange("POST_EXPOSURE_MAX", 44.0, 1.0, 64.0, 0.5, false))
            .add(asFloatRange("POST_EXPOSURE_SPEED", 0.8, 0.05, 2.0, 0.05, false))
            .add(asFloatRange("POST_EXPOSURE_OFFSET", 3.8, -4.0, 12.0, 0.2, false))
            .build())
        .add(new Page("POST_TONEMAP")
            //.add("Uchimura ToneMap")
            .add(asFloatRange("POST_TONEMAP_CONTRAST", 0.98, 0.02, 2.0, 0.02, false))
            .add(asFloatRange("POST_TONEMAP_LINEAR_START", 0.08, 0.02, 1.0, 0.02, false))
            .add(asFloatRange("POST_TONEMAP_LINEAR_LENGTH", 0.30, 0.02, 1.0, 0.02, false))
            .add(asFloatRange("POST_TONEMAP_BLACK", 1.36, 0.02, 3.0, 0.02, false))
            .build())
        .add(asBool('POST_PURKINJE_ENABLED', true, true))
        //.add(asIntRange("POST_PURKINJE_STRENGTH", 30, 0, 100, 2, false))
        .build();

    const screen_Debug = new Page('DEBUG')
        .add(asStringRange('DEBUG_VIEW', 0, 0, 12, true))
        .add(asStringRange('DEBUG_MATERIAL', 0, 0, 9, true))
        .add(asBool('DEBUG_TRANSLUCENT', false, true))
        .add(EMPTY)
        .add(asBool('DEBUG_LIGHT_COUNT', false, true))
        .add(asBool('DEBUG_EXPOSURE', false, true))
        .add(asBool('DEBUG_WHITE_WORLD', false, true))
        .build();

    return new Page('main')
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
    const values = getValueRange(valueMin, valueMax, interval);
    return asFloat(keyName, ...values).needsReload(reload).build(defaultValue);
}

function asStringRange(keyName: String, defaultValue: Number, valueMin: Number, valueMax: Number, reload: Boolean = true) {
    const values = getValueRange(valueMin, valueMax, 1);
    return asString(keyName, ...values.map(v => v.toString())).needsReload(reload).build(defaultValue.toString());
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
