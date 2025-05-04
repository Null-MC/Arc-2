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
    Sky_SunAngle = () => getIntSetting("SKY_SUN_ANGLE");
    Sky_SeaLevel = () => getIntSetting("SKY_SEA_LEVEL");
    Sky_Clouds = () => getBoolSetting("SKY_CLOUDS_ENABLED");
    Sky_FogDensity = () => getIntSetting("SKY_FOG_DENSITY");
    Sky_FogNoise = () => getBoolSetting("SKY_FOG_NOISE");
    Water_WaveEnabled = () => getBoolSetting("WATER_WAVES_ENABLED");
    Water_WaveDetail = () => getIntSetting("WATER_WAVES_DETAIL");
    Water_Tessellation = () => getBoolSetting("WATER_TESSELLATION_ENABLED");
    Water_TessellationLevel = () => getIntSetting("WATER_TESSELLATION_LEVEL");
    Shadow_Enabled = () => getBoolSetting("SHADOWS_ENABLED");
    Shadow_CloudEnabled = () => getBoolSetting("SHADOWS_CLOUD_ENABLED");
    Shadow_Resolution = () => getIntSetting("SHADOW_RESOLUTION");
    Shadow_Filter = () => true;
    Shadow_SS_Fallback = () => true;
    Material_Format = () => parseInt(getStringSetting("MATERIAL_FORMAT"));
    Material_ParallaxEnabled = () => getBoolSetting("MATERIAL_PARALLAX_ENABLED");
    Material_ParallaxDepth = () => getIntSetting("MATERIAL_PARALLAX_DEPTH");
    Material_ParallaxStepCount = () => getIntSetting("MATERIAL_PARALLAX_SAMPLES");
    Material_ParallaxSharp = () => getBoolSetting("MATERIAL_PARALLAX_SHARP");
    Material_ParallaxDepthWrite = () => getBoolSetting("MATERIAL_PARALLAX_DEPTHWRITE");
    Material_NormalSmooth = () => getBoolSetting("MATERIAL_NORMAL_SMOOTH");
    Material_EmissionBrightness = () => getIntSetting("MATERIAL_EMISSION_BRIGHTNESS");
    Material_FancyLava = () => getBoolSetting("FANCY_LAVA");
    Material_FancyLavaResolution = () => getIntSetting("FANCY_LAVA_RES");
    Lighting_Mode = () => parseInt(getStringSetting("LIGHTING_MODE"));
    Lighting_LpvRsmEnabled = () => false;
    Lighting_TraceSampleCount = () => getIntSetting("RT_MAX_SAMPLE_COUNT");
    Lighting_TraceQuads = () => getBoolSetting("LIGHTING_TRACE_TRIANGLE");
    Lighting_ReflectionMode = () => getStringSettingIndex("LIGHTING_REFLECT_MODE", 2, 'Sky Only', 'Screen-Space', 'World-Space');
    Lighting_ReflectionNoise = () => getBoolSetting("LIGHTING_REFLECT_NOISE");
    Lighting_ReflectionQuads = () => getBoolSetting("LIGHTING_REFLECT_TRIANGLE");
    Lighting_ReflectionStepCount = () => getIntSetting("LIGHTING_REFLECT_MAXSTEP");
    Lighting_VolumetricResolution = () => getIntSetting("LIGHTING_VL_RES");
    Voxel_Size = () => getIntSetting("VOXEL_SIZE");
    Voxel_Offset = () => getIntSetting("VOXEL_FRUSTUM_OFFSET");
    Voxel_GI_Enabled = () => getBoolSetting("VOXEL_GI_ENABLED");
    Voxel_MaxLightCount = () => 64;
    Voxel_MaxQuadCount = () => 64;
    Voxel_UseProvided = () => getBoolSetting("VOXEL_PROVIDED");
    Effect_SSAO_Enabled = () => getBoolSetting("EFFECT_SSAO_ENABLED");
    Effect_SSGI_Enabled = () => getBoolSetting("EFFECT_SSGI_ENABLED");
    Effect_SSGIAO_StepCount = () => getIntSetting("EFFECT_SSGIAO_SAMPLES");
    Effect_BloomEnabled = () => getBoolSetting("EFFECT_BLOOM_ENABLED");
    Effect_BloomStrength = () => getFloatSetting("EFFECT_BLOOM_STRENGTH");
    Effect_TAA_Enabled = () => getBoolSetting("EFFECT_TAA_ENABLED");
    Post_ExposureMin = () => getFloatSetting("POST_EXPOSURE_MIN");
    Post_ExposureMax = () => getFloatSetting("POST_EXPOSURE_MAX");
    Post_ExposureRange = () => getFloatSetting("POST_EXPOSURE_RANGE");
    Post_ExposureSpeed = () => getFloatSetting("POST_EXPOSURE_SPEED");
    Post_Contrast = () => getIntSetting("POST_CONTRAST");
    Debug_View = () => getStringSettingIndex("DEBUG_VIEW", 0, 'None', 'Material', 'Shadows', 'SSS', 'SSAO', 'SSGI', 'Volumetric Lighting', 'Ray-Traced Lighting', 'Accumulation', 'Sky Irradiance', 'ShadowMap Color', 'ShadowMap Normal');
    Debug_Material = () => getStringSettingIndex("DEBUG_MATERIAL", 0, 'Albedo', 'Geo-Normal', 'Tex-Normal', 'Occlusion', 'Roughness', 'F0/Metal', 'Porosity', 'SSS', 'Emission', 'LightMap');
    Debug_WhiteWorld = () => getBoolSetting("DEBUG_WHITE_WORLD");
    Debug_Translucent = () => getBoolSetting("DEBUG_TRANSLUCENT");
    Debug_Histogram = () => false;
    Debug_RT = () => false;


    getSnapshot() : SettingsSnapshot {
        const snapshot = new SettingsSnapshot();
        snapshot.Sky_SunAngle = this.Sky_SunAngle();
        snapshot.Sky_SeaLevel = this.Sky_SeaLevel();
        snapshot.Sky_Clouds = this.Sky_Clouds();
        snapshot.Sky_FogDensity = this.Sky_FogDensity();
        snapshot.Sky_FogNoise = this.Sky_FogNoise();
        snapshot.Water_WaveEnabled = this.Water_WaveEnabled();
        snapshot.Water_WaveDetail = this.Water_WaveDetail();
        snapshot.Water_Tessellation = this.Water_Tessellation();
        snapshot.Water_TessellationLevel = this.Water_TessellationLevel();
        snapshot.Shadow_Enabled = this.Shadow_Enabled();
        snapshot.Shadow_CloudEnabled = this.Shadow_CloudEnabled();
        snapshot.Shadow_Resolution = this.Shadow_Resolution();
        snapshot.Shadow_Filter = this.Shadow_Filter();
        snapshot.Shadow_SS_Fallback = this.Shadow_SS_Fallback();
        snapshot.Material_Format = this.Material_Format();
        snapshot.Material_ParallaxEnabled = this.Material_ParallaxEnabled();
        snapshot.Material_ParallaxDepth = this.Material_ParallaxDepth();
        snapshot.Material_ParallaxStepCount = this.Material_ParallaxStepCount();
        snapshot.Material_ParallaxSharp = this.Material_ParallaxSharp();
        snapshot.Material_ParallaxDepthWrite = this.Material_ParallaxDepthWrite();
        snapshot.Material_NormalSmooth = this.Material_NormalSmooth();
        snapshot.Material_EmissionBrightness = this.Material_EmissionBrightness();
        snapshot.Material_FancyLava = this.Material_FancyLava();
        snapshot.Material_FancyLavaResolution = this.Material_FancyLavaResolution();
        snapshot.Lighting_Mode = this.Lighting_Mode();
        snapshot.Lighting_LpvRsmEnabled = this.Lighting_LpvRsmEnabled();
        snapshot.Lighting_TraceSampleCount = this.Lighting_TraceSampleCount();
        snapshot.Lighting_TraceQuads = this.Lighting_TraceQuads();
        snapshot.Lighting_ReflectionMode = this.Lighting_ReflectionMode();
        snapshot.Lighting_ReflectionNoise = this.Lighting_ReflectionNoise();
        snapshot.Lighting_ReflectionQuads = this.Lighting_ReflectionQuads();
        snapshot.Lighting_ReflectionStepCount = this.Lighting_ReflectionStepCount();
        snapshot.Lighting_VolumetricResolution = this.Lighting_VolumetricResolution();
        snapshot.Voxel_Size = this.Voxel_Size();
        snapshot.Voxel_Offset = this.Voxel_Offset();
        snapshot.Voxel_GI_Enabled = this.Voxel_GI_Enabled();
        snapshot.Voxel_MaxLightCount = this.Voxel_MaxLightCount();
        snapshot.Voxel_MaxQuadCount = this.Voxel_MaxQuadCount();
        snapshot.Voxel_UseProvided = this.Voxel_UseProvided();
        snapshot.Effect_SSAO_Enabled = this.Effect_SSAO_Enabled();
        snapshot.Effect_SSGI_Enabled = this.Effect_SSGI_Enabled();
        snapshot.Effect_SSGIAO_StepCount = this.Effect_SSGIAO_StepCount();
        snapshot.Effect_BloomEnabled = this.Effect_BloomEnabled();
        snapshot.Effect_BloomStrength = this.Effect_BloomStrength();
        snapshot.Effect_TAA_Enabled = this.Effect_TAA_Enabled();
        snapshot.Post_ExposureMin = this.Post_ExposureMin();
        snapshot.Post_ExposureMax = this.Post_ExposureMax();
        snapshot.Post_ExposureRange = this.Post_ExposureRange();
        snapshot.Post_ExposureSpeed = this.Post_ExposureSpeed();
        snapshot.Post_Contrast = this.Post_Contrast();
        snapshot.Debug_View = this.Debug_View();
        snapshot.Debug_Material = this.Debug_Material();
        snapshot.Debug_WhiteWorld = this.Debug_WhiteWorld();
        snapshot.Debug_Translucent = this.Debug_Translucent();
        snapshot.Debug_Histogram = this.Debug_Histogram();
        snapshot.Debug_RT = this.Debug_RT();
        return snapshot;
    }

    getRealTimeSnapshot() : RealTimeSettingsSnapshot {
        const snapshot = new RealTimeSettingsSnapshot();
        snapshot.Sky_SunAngle = this.Sky_SunAngle();
        snapshot.Sky_SeaLevel = this.Sky_SeaLevel();
        snapshot.Sky_FogDensity = this.Sky_FogDensity();
        snapshot.Water_WaveDetail = this.Water_WaveDetail();
        snapshot.Material_EmissionBrightness = this.Material_EmissionBrightness();
        snapshot.Effect_BloomStrength = this.Effect_BloomStrength();
        snapshot.Post_ExposureMin = this.Post_ExposureMin();
        snapshot.Post_ExposureMax = this.Post_ExposureMax();
        snapshot.Post_ExposureRange = this.Post_ExposureRange();
        snapshot.Post_ExposureSpeed = this.Post_ExposureSpeed();
        snapshot.Post_Contrast = this.Post_Contrast();
        return snapshot;
    }
}

function getStringSettingIndex(name: string, defaultValue: number, ...options: string[]) : number {
    const value = getStringSetting(name);
    const index = options.indexOf(value);
    //print(`Setting [${name}] = [${index}] where [${name}] in [${options}]`)
    return index < 0 ? defaultValue : index;
}

export function buildSettings(snapshot: SettingsSnapshot) {
    const settings = {
        snapshot: snapshot,
        Internal: {
            Accumulation: false,
            Voxelization: false,
            VoxelizeBlockFaces: false,
            VoxelizeTriangles: false,
            DebugEnabled: false,
            LPV: false,
        },
    };

    if (snapshot.Effect_SSAO_Enabled) settings.Internal.Accumulation = true;
    if (snapshot.Effect_SSGI_Enabled) settings.Internal.Accumulation = true;

    switch (snapshot.Lighting_Mode) {
        case LightingModes.FloodFill:
            settings.Internal.Voxelization = true;
            settings.Internal.LPV = true;
            break;
        case LightingModes.RayTraced:
            settings.Internal.Voxelization = true;
            settings.Internal.Accumulation = true;

            if (snapshot.Lighting_TraceQuads)
                settings.Internal.VoxelizeTriangles = true;
            break;
    }

    if (snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        settings.Internal.Voxelization = true;
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

    if (snapshot.Lighting_LpvRsmEnabled) {
        settings.Internal.Voxelization = true;
        settings.Internal.LPV = true;
    }

    if (snapshot.Voxel_GI_Enabled) {
        settings.Internal.Voxelization = true;
        settings.Internal.VoxelizeBlockFaces = true;
        settings.Internal.LPV = true;
    }

    if (snapshot.Debug_View != 0)
        settings.Internal.DebugEnabled = true;

    // TODO: DEBUG ONLY!
    //Settings.Internal.Accumulation = false;

    return settings;
}

export class SettingsSnapshot {
    Sky_SunAngle: number;
    Sky_SeaLevel: number;
    Sky_Clouds: boolean;
    Sky_FogDensity: number;
    Sky_FogNoise: boolean;
    Water_WaveEnabled: boolean;
    Water_WaveDetail: number;
    Water_Tessellation: boolean;
    Water_TessellationLevel: number;
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
    Material_NormalSmooth: boolean;
    Material_EmissionBrightness: number;
    Material_FancyLava: boolean;
    Material_FancyLavaResolution: number;
    Lighting_Mode: number;
    Lighting_LpvRsmEnabled: boolean;
    Lighting_TraceSampleCount: number;
    Lighting_TraceQuads: boolean;
    Lighting_ReflectionMode: number;
    Lighting_ReflectionNoise: boolean;
    Lighting_ReflectionQuads: boolean;
    Lighting_ReflectionStepCount: number;
    Lighting_VolumetricResolution: number;
    Voxel_Size: number;
    Voxel_Offset: number;
    Voxel_GI_Enabled: boolean;
    Voxel_MaxLightCount: number;
    Voxel_MaxQuadCount: number;
    Voxel_UseProvided: boolean;
    Effect_SSAO_Enabled: boolean;
    Effect_SSGI_Enabled: boolean;
    Effect_SSGIAO_StepCount: number;
    Effect_BloomEnabled: boolean;
    Effect_BloomStrength: number;
    Effect_TAA_Enabled: boolean;
    Post_ExposureMin: number;
    Post_ExposureMax: number;
    Post_ExposureRange: number;
    Post_ExposureSpeed: number;
    Post_Contrast: number;
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
    Sky_FogDensity: number;
    Water_WaveDetail: number;
    Material_EmissionBrightness: number;
    Effect_BloomStrength: number;
    Post_Contrast: number;
    Post_ExposureMin: number;
    Post_ExposureMax: number;
    Post_ExposureRange: number;
    Post_ExposureSpeed: number;
}
