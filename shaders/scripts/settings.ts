import type {} from '../iris'


export enum LightingModes {
    LightMap,
    FloodFill,
    RayTraced,
}

export enum ReflectionModes {
    SkyOnly,
    ScreenSpace,
    WorldSpace,
}

export class ShaderSettings {
    getStaticSnapshot() : StaticSettingsSnapshot {
        const snapshot = new StaticSettingsSnapshot();
        snapshot.Sky_Clouds = getBoolSetting("SKY_CLOUDS_ENABLED");
        snapshot.Sky_FogNoise = getBoolSetting("SKY_FOG_NOISE");
        snapshot.Sky_Fog_CaveEnabled = getBoolSetting("FOG_CAVE_ENABLED");
        snapshot.Water_WaveEnabled = getBoolSetting("WATER_WAVES_ENABLED");
        snapshot.Water_Tessellation = getBoolSetting("WATER_TESSELLATION_ENABLED");
        snapshot.Shadow_Enabled = getBoolSetting("SHADOWS_ENABLED");
        snapshot.Shadow_CloudEnabled = getBoolSetting("SHADOWS_CLOUD_ENABLED");
        snapshot.Shadow_Resolution = getIntSetting("SHADOW_RESOLUTION");
        snapshot.Shadow_Filter = true;
        snapshot.Shadow_SS_Fallback = true;
        snapshot.Material_Format = parseInt(getStringSetting("MATERIAL_FORMAT"));
        snapshot.Material_ParallaxEnabled = getBoolSetting("MATERIAL_PARALLAX_ENABLED");
        snapshot.Material_ParallaxDepth = getIntSetting("MATERIAL_PARALLAX_DEPTH");
        snapshot.Material_ParallaxStepCount = getIntSetting("MATERIAL_PARALLAX_SAMPLES");
        snapshot.Material_ParallaxSharp = getBoolSetting("MATERIAL_PARALLAX_SHARP");
        snapshot.Material_ParallaxDepthWrite = getBoolSetting("MATERIAL_PARALLAX_DEPTHWRITE");
        snapshot.Material_NormalFormat = parseInt(getStringSetting("MATERIAL_NORMAL_FORMAT"));
        snapshot.Material_NormalSmooth = getBoolSetting("MATERIAL_NORMAL_SMOOTH");
        snapshot.Material_PorosityFormat = parseInt(getStringSetting("MATERIAL_POROSITY_FORMAT"));
        snapshot.Material_EmissionBrightness = getIntSetting("MATERIAL_EMISSION_BRIGHTNESS");
        snapshot.Material_FancyLava = getBoolSetting("FANCY_LAVA");
        snapshot.Material_FancyLavaResolution = getIntSetting("FANCY_LAVA_RES");
        snapshot.Lighting_Mode = parseInt(getStringSetting("LIGHTING_MODE"));
        snapshot.Lighting_GI_Enabled = getBoolSetting("LIGHTING_GI_ENABLED");
        snapshot.Lighting_GI_SkyLight = getBoolSetting("LIGHTING_GI_SKYLIGHT");
        snapshot.Lighting_TraceSampleCount = getIntSetting("RT_MAX_SAMPLE_COUNT");
        snapshot.Lighting_TraceLightMax = getIntSetting("RT_MAX_LIGHT_COUNT");
        snapshot.Lighting_TraceQuads = getBoolSetting("LIGHTING_TRACE_TRIANGLE");
        snapshot.Lighting_ReflectionMode = parseInt(getStringSetting("LIGHTING_REFLECT_MODE"));
        snapshot.Lighting_ReflectionNoise = getBoolSetting("LIGHTING_REFLECT_NOISE");
        snapshot.Lighting_ReflectionQuads = getBoolSetting("LIGHTING_REFLECT_TRIANGLE");
        snapshot.Lighting_ReflectionStepCount = getIntSetting("LIGHTING_REFLECT_MAXSTEP");
        snapshot.Lighting_VolumetricResolution = getIntSetting("LIGHTING_VL_RES");
        snapshot.Lighting_ColorCandles = getBoolSetting("LIGHTING_COLOR_CANDLES");
        snapshot.Voxel_Size = getIntSetting("VOXEL_SIZE");
        snapshot.Voxel_Offset = getIntSetting("VOXEL_FRUSTUM_OFFSET");
        snapshot.Voxel_MaxQuadCount = 64;
        snapshot.Voxel_UseProvided = getBoolSetting("VOXEL_PROVIDED");
        snapshot.Effect_SSAO_Enabled = getBoolSetting("EFFECT_SSAO_ENABLED");
        snapshot.Effect_SSAO_StepCount = getIntSetting("EFFECT_SSAO_SAMPLES");
        snapshot.Effect_BloomEnabled = getBoolSetting("EFFECT_BLOOM_ENABLED");
        snapshot.Effect_TAA_Enabled = getBoolSetting("EFFECT_TAA_ENABLED");
        snapshot.Debug_View = getStringSettingIndex("DEBUG_VIEW", 0, 'None', 'Material', 'Shadows', 'SSS', 'SSAO', 'Volumetric Lighting', 'Ray-Traced Lighting', 'Accumulation', 'Sky Irradiance', 'ShadowMap Color', 'ShadowMap Normal');
        snapshot.Debug_Material = getStringSettingIndex("DEBUG_MATERIAL", 0, 'Albedo', 'Geo-Normal', 'Tex-Normal', 'Occlusion', 'Roughness', 'F0/Metal', 'Porosity', 'SSS', 'Emission', 'LightMap');
        snapshot.Debug_WhiteWorld = getBoolSetting("DEBUG_WHITE_WORLD");
        snapshot.Debug_Translucent = getBoolSetting("DEBUG_TRANSLUCENT");
        snapshot.Debug_Histogram = false;
        snapshot.Debug_RT = false;
        return snapshot;
    }

    getRealTimeSnapshot() : RealTimeSettingsSnapshot {
        const snapshot = new RealTimeSettingsSnapshot();
        snapshot.Sky_SunAngle = getIntSetting("SKY_SUN_ANGLE");
        snapshot.Sky_SeaLevel = getIntSetting("SKY_SEA_LEVEL");
        snapshot.Sky_CloudCoverage = getIntSetting("SKY_CLOUD_COVERAGE");
        snapshot.Sky_FogDensity = getIntSetting("SKY_FOG_DENSITY");
        snapshot.Water_WaveDetail = getIntSetting("WATER_WAVES_DETAIL");
        snapshot.Water_WaveHeight = getFloatSetting("WATER_WAVES_HEIGHT");
        snapshot.Water_TessellationLevel = getIntSetting("WATER_TESSELLATION_LEVEL");
        snapshot.Material_EmissionBrightness = getIntSetting("MATERIAL_EMISSION_BRIGHTNESS");
        snapshot.Lighting_BlockTemp = getIntSetting("BLOCKLIGHT_TEMP");
        snapshot.Lighting_PenumbraSize = getIntSetting("LIGHT_TRACE_PENUMBRA");
        snapshot.Effect_BloomStrength = getFloatSetting("EFFECT_BLOOM_STRENGTH");
        snapshot.Post_ExposureMin = getFloatSetting("POST_EXPOSURE_MIN");
        snapshot.Post_ExposureMax = getFloatSetting("POST_EXPOSURE_MAX");
        snapshot.Post_ExposureRange = getFloatSetting("POST_EXPOSURE_RANGE");
        snapshot.Post_ExposureSpeed = getFloatSetting("POST_EXPOSURE_SPEED");
        snapshot.Post_ToneMap_Contrast = getFloatSetting("POST_TONEMAP_CONTRAST");
        snapshot.Post_ToneMap_LinearStart = getFloatSetting("POST_TONEMAP_LINEAR_START");
        snapshot.Post_ToneMap_LinearLength = getFloatSetting("POST_TONEMAP_LINEAR_LENGTH");
        snapshot.Post_ToneMap_Black = getFloatSetting("POST_TONEMAP_BLACK");
        return snapshot;
    }
}

function getStringSettingIndex(name: string, defaultValue: number, ...options: string[]) : number {
    const value = getStringSetting(name);
    const index = options.indexOf(value);
    return index < 0 ? defaultValue : index;
}

export function buildSettings(snapshot: StaticSettingsSnapshot, realtime: RealTimeSettingsSnapshot) {
    const settings = {
        snapshot: snapshot,
        realtime: realtime,
        Internal: {
            Accumulation: false,
            VoxelizeBlocks: false,
            VoxelizeBlockFaces: false,
            VoxelizeTriangles: false,
            DebugEnabled: false,
        },
    };

    if (snapshot.Effect_SSAO_Enabled) settings.Internal.Accumulation = true;

    switch (snapshot.Lighting_Mode) {
        case LightingModes.FloodFill:
            settings.Internal.VoxelizeBlocks = true;
            break;
        case LightingModes.RayTraced:
            settings.Internal.VoxelizeBlocks = true;
            settings.Internal.Accumulation = true;

            if (snapshot.Lighting_TraceQuads)
                settings.Internal.VoxelizeTriangles = true;
            break;
    }

    if (snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        settings.Internal.VoxelizeBlocks = true;
        settings.Internal.Accumulation = true;

        if (snapshot.Lighting_ReflectionQuads) {
            settings.Internal.VoxelizeTriangles = true;
        }
        else {
            settings.Internal.VoxelizeBlockFaces = true;
        }

        // if (settings.Lighting.Mode == LightMode_RT) {
        //     settings.Internal.Voxelization = true;
        //     settings.Internal.LPV = true;
        // }
    }

    if (snapshot.Lighting_GI_Enabled) {
        settings.Internal.VoxelizeBlocks = true;
        settings.Internal.VoxelizeBlockFaces = true;
    }

    if (snapshot.Debug_View != 0)
        settings.Internal.DebugEnabled = true;

    return settings;
}

export class StaticSettingsSnapshot {
    Sky_Clouds: boolean;
    Sky_FogNoise: boolean;
    Sky_Fog_CaveEnabled: boolean;
    Water_WaveEnabled: boolean;
    Water_Tessellation: boolean;
    Shadow_Enabled: boolean;
    Shadow_CloudEnabled: boolean;
    Shadow_Resolution: number;
    Shadow_Filter: boolean;
    Shadow_SS_Fallback: boolean;
    Material_Format: number;
    Material_ParallaxEnabled: boolean;
    Material_ParallaxDepth: number;
    Material_ParallaxStepCount: number;
    Material_ParallaxSharp: boolean;
    Material_ParallaxDepthWrite: boolean;
    Material_NormalFormat: number;
    Material_NormalSmooth: boolean;
    Material_PorosityFormat: number;
    Material_EmissionBrightness: number;
    Material_FancyLava: boolean;
    Material_FancyLavaResolution: number;
    Lighting_Mode: number;
    Lighting_TraceSampleCount: number;
    Lighting_TraceLightMax: number;
    Lighting_TraceQuads: boolean;
    Lighting_ReflectionMode: number;
    Lighting_ReflectionNoise: boolean;
    Lighting_ReflectionQuads: boolean;
    Lighting_ReflectionStepCount: number;
    Lighting_VolumetricResolution: number;
    Lighting_ColorCandles: boolean;
    Lighting_GI_Enabled: boolean;
    Lighting_GI_SkyLight: boolean;
    Voxel_Size: number;
    Voxel_Offset: number;
    Voxel_MaxQuadCount: number;
    Voxel_UseProvided: boolean;
    Effect_SSAO_Enabled: boolean;
    Effect_SSAO_StepCount: number;
    Effect_BloomEnabled: boolean;
    Effect_TAA_Enabled: boolean;
    Debug_View: number;
    Debug_Material: number;
    Debug_WhiteWorld: boolean;
    Debug_Translucent: boolean;
    Debug_Histogram: boolean;
    Debug_RT: boolean;
}

export class RealTimeSettingsSnapshot {
    Sky_SunAngle: number;
    Sky_SeaLevel: number;
    Sky_CloudCoverage: number;
    Sky_FogDensity: number;
    Water_WaveDetail: number;
    Water_WaveHeight: number;
    Water_TessellationLevel: number;
    Material_EmissionBrightness: number;
    Lighting_BlockTemp: number;
    Lighting_PenumbraSize: number;
    Effect_BloomStrength: number;
    Post_ExposureMin: number;
    Post_ExposureMax: number;
    Post_ExposureRange: number;
    Post_ExposureSpeed: number;
    Post_ToneMap_Contrast: number;
    Post_ToneMap_LinearStart: number;
    Post_ToneMap_LinearLength: number;
    Post_ToneMap_Black: number;
}
