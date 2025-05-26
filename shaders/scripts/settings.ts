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
    _cache: Record<string, string|number|boolean> = {};

    get Sky_SunAngle(): number {return this.getCachedIntSetting("SKY_SUN_ANGLE");}
    get Sky_SeaLevel(): number {return this.getCachedIntSetting("SKY_SEA_LEVEL");}
    get Sky_CloudsEnabled(): boolean {return this.getCachedBoolSetting("SKY_CLOUDS_ENABLED");}
    get Sky_CloudCoverage(): number {return this.getCachedIntSetting("SKY_CLOUD_COVERAGE");}

    get Fog_Density(): number {return this.getCachedIntSetting("SKY_FOG_DENSITY");}
    get Fog_NoiseEnabled(): boolean {return this.getCachedBoolSetting("SKY_FOG_NOISE");}
    get Fog_CaveEnabled(): boolean {return this.getCachedBoolSetting("FOG_CAVE_ENABLED");}

    get Water_WaveEnabled(): boolean {return this.getCachedBoolSetting("WATER_WAVES_ENABLED");}
    get Water_WaveDetail(): number {return this.getCachedIntSetting("WATER_WAVES_DETAIL");}
    get Water_WaveHeight(): number {return this.getCachedFloatSetting("WATER_WAVES_HEIGHT");}
    get Water_TessellationEnabled(): boolean {return this.getCachedBoolSetting("WATER_TESSELLATION_ENABLED");}
    get Water_TessellationLevel(): number {return this.getCachedIntSetting("WATER_TESSELLATION_LEVEL");}

    get Shadow_Enabled(): boolean {return this.getCachedBoolSetting("SHADOWS_ENABLED");}
    get Shadow_Resolution(): number {return this.getCachedIntSetting("SHADOW_RESOLUTION");}
    get Shadow_CascadeCount(): number {return this.getCachedIntSetting("SHADOW_CASCADE_COUNT");}
    get Shadow_CloudEnabled(): boolean {return this.getCachedBoolSetting("SHADOWS_CLOUD_ENABLED");}
    get Shadow_Filter(): boolean {return true;}
    get Shadow_SS_Fallback(): boolean {return this.getCachedBoolSetting("SHADOWS_SS_FALLBACK");}

    get Material_Format(): number {return this.getCachedSetting<number>("MATERIAL_FORMAT", k => parseInt(getStringSetting(k)));}
    get Material_ParallaxEnabled(): boolean {return this.getCachedBoolSetting("MATERIAL_PARALLAX_ENABLED");}
    get Material_ParallaxDepth(): number {return this.getCachedIntSetting("MATERIAL_PARALLAX_DEPTH");}
    get Material_ParallaxStepCount(): number {return this.getCachedIntSetting("MATERIAL_PARALLAX_SAMPLES");}
    get Material_ParallaxSharp(): boolean {return this.getCachedBoolSetting("MATERIAL_PARALLAX_SHARP");}
    get Material_ParallaxDepthWrite(): boolean {return this.getCachedBoolSetting("MATERIAL_PARALLAX_DEPTHWRITE");}
    get Material_NormalFormat(): number {return this.getCachedSetting<number>("MATERIAL_NORMAL_FORMAT", k => parseInt(getStringSetting(k)));}
    get Material_NormalSmooth(): boolean {return this.getCachedBoolSetting("MATERIAL_NORMAL_SMOOTH");}
    get Material_PorosityFormat(): number {return this.getCachedSetting<number>("MATERIAL_POROSITY_FORMAT", k => parseInt(getStringSetting(k)));}
    get Material_EmissionBrightness(): number {return this.getCachedIntSetting("MATERIAL_EMISSION_BRIGHTNESS");}
    get Material_SSS_Format(): number {return this.getCachedSetting<number>("MATERIAL_SSS_FORMAT", k => parseInt(getStringSetting(k)));}
    get Material_SSS_MaxDist(): number {return this.getCachedFloatSetting("MATERIAL_SSS_DISTANCE");}
    get Material_SSS_MaxRadius(): number {return this.getCachedFloatSetting("MATERIAL_SSS_RADIUS");}
    get Material_FancyLava(): boolean {return this.getCachedBoolSetting("FANCY_LAVA");}
    get Material_FancyLavaResolution(): number {return this.getCachedIntSetting("FANCY_LAVA_RES");}

    get Lighting_Mode(): number {return this.getCachedSetting<number>("LIGHTING_MODE", k => parseInt(getStringSetting(k)));}
    get Lighting_BlockTemp(): number {return this.getCachedIntSetting("BLOCKLIGHT_TEMP");}
    get Lighting_ColorCandles(): boolean {return this.getCachedBoolSetting("LIGHTING_COLOR_CANDLES");}
    get Lighting_GI_Enabled(): boolean {return this.getCachedBoolSetting("LIGHTING_GI_ENABLED");}
    get Lighting_GI_SkyLight(): boolean {return this.getCachedBoolSetting("LIGHTING_GI_SKYLIGHT");}
    get Lighting_GI_MaxSteps(): number {return this.getCachedIntSetting("VOXEL_GI_MAXSTEP");}
    get Lighting_GI_BuffserSize(): number {return this.getCachedIntSetting("LIGHTING_GI_SIZE");}
    get Lighting_GI_CascadeCount(): number {return this.getCachedIntSetting("LIGHTING_GI_CASCADES");}
    get Lighting_GI_MaxFrames(): number {return this.getCachedIntSetting("VOXEL_GI_MAXFRAMES");}
    get Lighting_GI_BaseScale(): number {return this.getCachedIntSetting("WSGI_SCALE_BASE");}
    get Lighting_PenumbraSize(): number {return this.getCachedIntSetting("LIGHT_TRACE_PENUMBRA");}
    get Lighting_TraceSampleCount(): number {return this.getCachedIntSetting("RT_MAX_SAMPLE_COUNT");}
    get Lighting_TraceLightMax(): number {return this.getCachedIntSetting("RT_MAX_LIGHT_COUNT");}
    get Lighting_TraceQuads(): boolean {return this.getCachedBoolSetting("LIGHTING_TRACE_TRIANGLE");}
    get Lighting_ReflectionMode(): number {return this.getCachedSetting<number>("LIGHTING_REFLECT_MODE", k => parseInt(getStringSetting(k)));}
    get Lighting_ReflectionNoise(): boolean {return this.getCachedBoolSetting("LIGHTING_REFLECT_NOISE");}
    get Lighting_ReflectionQuads(): boolean {return this.getCachedBoolSetting("LIGHTING_REFLECT_TRIANGLE");}
    get Lighting_ReflectionStepCount(): number {return this.getCachedIntSetting("LIGHTING_REFLECT_MAXSTEP");}
    get Lighting_VolumetricResolution(): number {return this.getCachedIntSetting("LIGHTING_VL_RES");}

    get Voxel_Size(): number {return this.getCachedIntSetting("VOXEL_SIZE");}
    get Voxel_Offset(): number {return this.getCachedIntSetting("VOXEL_FRUSTUM_OFFSET");}
    get Voxel_MaxQuadCount(): number {return 64;}
    get Voxel_UseProvided(): boolean {return this.getCachedBoolSetting("VOXEL_PROVIDED");}

    get Effect_SSAO_Enabled(): boolean {return this.getCachedBoolSetting("EFFECT_SSAO_ENABLED");}
    get Effect_SSAO_Strength(): number {return this.getCachedIntSetting("EFFECT_SSAO_STRENGTH");}
    get Effect_SSAO_StepCount(): number {return this.getCachedIntSetting("EFFECT_SSAO_SAMPLES");}
    get Effect_Bloom_Enabled(): boolean {return this.getCachedBoolSetting("EFFECT_BLOOM_ENABLED");}
    get Effect_Bloom_Strength(): number {return this.getCachedFloatSetting("EFFECT_BLOOM_STRENGTH");}
    get Effect_DOF_Enabled(): boolean {return this.getCachedBoolSetting("EFFECT_DOF_ENABLED");}
    get Effect_DOF_Speed(): number {return this.getCachedIntSetting("EFFECT_DOF_SPEED");}

    get Post_TAA_Enabled(): boolean {return this.getCachedBoolSetting("EFFECT_TAA_ENABLED");}
    get Post_ExposureMin(): number {return this.getCachedFloatSetting("POST_EXPOSURE_MIN");}
    get Post_ExposureMax(): number {return this.getCachedFloatSetting("POST_EXPOSURE_MAX");}
    get Post_ExposureSpeed(): number {return this.getCachedFloatSetting("POST_EXPOSURE_SPEED");}
    get Post_ExposureOffset(): number {return this.getCachedFloatSetting("POST_EXPOSURE_OFFSET");}
    get Post_ToneMap_Contrast(): number {return this.getCachedFloatSetting("POST_TONEMAP_CONTRAST");}
    get Post_ToneMap_LinearStart(): number {return this.getCachedFloatSetting("POST_TONEMAP_LINEAR_START");}
    get Post_ToneMap_LinearLength(): number {return this.getCachedFloatSetting("POST_TONEMAP_LINEAR_LENGTH");}
    get Post_ToneMap_Black(): number {return this.getCachedFloatSetting("POST_TONEMAP_BLACK");}
    get Post_PurkinjeEnabled(): boolean {return this.getCachedBoolSetting("POST_PURKINJE_ENABLED");}
    //get Post_PurkinjeStrength(): number {return this.getCachedIntSetting("POST_PURKINJE_STRENGTH");}

    get Debug_View(): number {return this.getCachedSetting<number>("DEBUG_VIEW", k => parseInt(getStringSetting(k)));}
    get Debug_Material(): number {return this.getCachedSetting<number>("DEBUG_MATERIAL", k => parseInt(getStringSetting(k)));}
    get Debug_WhiteWorld(): boolean {return this.getCachedBoolSetting("DEBUG_WHITE_WORLD");}
    get Debug_Translucent(): boolean {return this.getCachedBoolSetting("DEBUG_TRANSLUCENT");}
    get Debug_Exposure(): boolean {return this.getCachedBoolSetting("DEBUG_EXPOSURE");}
    get Debug_RT(): boolean {return false;}


    BuildInternalSettings() {
        const settings = {
            Accumulation: false,
            VoxelizeBlocks: false,
            VoxelizeBlockFaces: false,
            VoxelizeTriangles: false,
            DebugEnabled: false,
        };

        if (this.Effect_SSAO_Enabled) settings.Accumulation = true;

        switch (this.Lighting_Mode) {
            case LightingModes.FloodFill:
                settings.VoxelizeBlocks = true;
                break;
            case LightingModes.RayTraced:
                settings.VoxelizeBlocks = true;
                settings.Accumulation = true;

                if (this.Lighting_TraceQuads)
                    settings.VoxelizeTriangles = true;
                break;
        }

        if (this.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
            settings.VoxelizeBlocks = true;
            settings.Accumulation = true;

            if (this.Lighting_ReflectionQuads) {
                settings.VoxelizeTriangles = true;
            }
            else {
                settings.VoxelizeBlockFaces = true;
            }

            // if (settings.Lighting.Mode == LightMode_RT) {
            //     settings.Internal.Voxelization = true;
            //     settings.Internal.LPV = true;
            // }
        }

        if (this.Lighting_GI_Enabled) {
            settings.VoxelizeBlocks = true;
            settings.VoxelizeBlockFaces = true;
        }

        if (this.Debug_View != 0 || this.Debug_Exposure)
            settings.DebugEnabled = true;

        return settings;
    }

    private getCachedBoolSetting(key : string) : boolean {
        return this.getCachedSetting<boolean>(key, getBoolSetting);
    }

    private getCachedIntSetting(key : string) : number {
        return this.getCachedSetting<number>(key, getIntSetting);
    }

    private getCachedFloatSetting(key : string) : number {
        return this.getCachedSetting<number>(key, getFloatSetting);
    }

    private getCachedSetting<T extends string|number|boolean>(key : string, onUpdate : (key: string) => T) : T {
        let value = this._cache[key] as T;
        if (!value) {
            value = onUpdate(key);
            this._cache[key] = value;
        }
        return value;
    }}

function getStringSettingIndex(name: string, defaultValue: number, ...options: string[]) : number {
    const value = getStringSetting(name);
    const index = options.indexOf(value);
    return index < 0 ? defaultValue : index;
}
