import type {} from './iris'

const LIGHT_BIN_SIZE = 8;
const QUAD_BIN_SIZE = 2;

// CONSTANTS
const LightMode_LightMap = 0;
const LightMode_LPV = 1;
const LightMode_RT = 2;

const ReflectMode_None = 0;
const ReflectMode_SSR = 1;
const ReflectMode_WSR = 2;


function setupSettings() {
    const Settings = {
        Sky: {
            SunAngle: getIntSetting("SKY_SUN_ANGLE"),
            SeaLevel: getIntSetting("SKY_SEA_LEVEL"),
            FogDensity: getIntSetting("SKY_FOG_DENSITY"),
            FogNoise: getBoolSetting("SKY_FOG_NOISE"),
        },
        Water: {
            Waves: getBoolSetting("WATER_WAVES_ENABLED"),
            Tessellation: getBoolSetting("WATER_TESSELLATION_ENABLED"),
            Tessellation_Level: getIntSetting("WATER_TESSELLATION_LEVEL"),
        },
        Shadows: {
            Enabled: getBoolSetting("SHADOWS_ENABLED"),
            CloudsEnabled: getBoolSetting("SHADOWS_CLOUD_ENABLED"),
            Resolution: getIntSetting("SHADOW_RESOLUTION"),
            Filter: true,
            SS_Fallback: true,
        },
        Material: {
            Format: getIntSetting("MATERIAL_FORMAT"),
            Parallax: {
                Enabled: getBoolSetting("MATERIAL_PARALLAX_ENABLED"),
                Depth: getIntSetting("MATERIAL_PARALLAX_DEPTH"),
                Samples: getIntSetting("MATERIAL_PARALLAX_SAMPLES"),
                Sharp: getBoolSetting("MATERIAL_PARALLAX_SHARP"),
                DepthWrite: getBoolSetting("MATERIAL_PARALLAX_DEPTHWRITE"),
            },
            EmissionBrightness: getIntSetting("EMISSION_BRIGHTNESS"),
            FancyLava: getBoolSetting("FANCY_LAVA"),
            FancyLavaRes: getIntSetting("FANCY_LAVA_RES"),
        },
        Lighting: {
            Mode: getIntSetting("LIGHTING_MODE"),
            LpvRsmEnabled: getBoolSetting("LPV_RSM_ENABLED"),
            RT: {
                MaxSampleCount: getIntSetting("RT_MAX_SAMPLE_COUNT"),
                TraceTriangles: getBoolSetting("LIGHTING_TRACE_TRIANGLE"),
            },
            Reflections: {
                Mode: getIntSetting("LIGHTING_REFLECT_MODE"),
                Noise: getBoolSetting("LIGHTING_REFLECT_NOISE"),
                ReflectTriangles: getBoolSetting("LIGHTING_REFLECT_TRIANGLE"),
                MaxStepCount: getIntSetting("LIGHTING_REFLECT_MAXSTEP"),
            },
            VolumetricResolution: getIntSetting("LIGHTING_VL_RES"),
        },
        Voxel: {
            Size: getIntSetting("VOXEL_SIZE"),
            Offset: getIntSetting("VOXEL_FRUSTUM_OFFSET"),
            MaxLightCount: 64,
            MaxTriangleCount: 64,
        },
        Effect: {
            SSAO: getBoolSetting("EFFECT_SSAO_ENABLED"),
            SSGI: getBoolSetting("EFFECT_SSGI_ENABLED"),
            Bloom: getBoolSetting("EFFECT_BLOOM_ENABLED"),
            SSGIAO_Samples: getIntSetting("EFFECT_SSGIAO_SAMPLES"),
        },
        Post: {
            TAA: getBoolSetting("EFFECT_TAA_ENABLED"),
            Exposure: {
                Min: parseFloat(getStringSetting("POST_EXPOSURE_MIN")),
                Max: parseFloat(getStringSetting("POST_EXPOSURE_MAX")),
                Speed: parseFloat(getStringSetting("POST_EXPOSURE_SPEED")),
            },
            Contrast: getIntSetting("POST_CONTRAST"),
        },
        Debug: {
            Enabled: getBoolSetting("DEBUG_ENABLED"),
            View: getIntSetting("DEBUG_VIEW"),
            Material: getIntSetting("DEBUG_MATERIAL"),
            WhiteWorld: getBoolSetting("DEBUG_WHITE_WORLD"),
            HISTOGRAM: false,
            RT: false,
        },
        Internal: {
            Accumulation: false,
            Voxelization: false,
            VoxelizeBlockFaces: false,
            VoxelizeTriangles: false,
            LPV: false,
        },
    };

    // if (Settings.Voxel.RT.Enabled) Settings.Internal.Accumulation = true;
    if (Settings.Effect.SSGI) Settings.Internal.Accumulation = true;

    if (Settings.Lighting.Mode == LightMode_LPV) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.LPV = true;
    }

    if (Settings.Lighting.Mode == LightMode_RT) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.Accumulation = true;

        if (Settings.Lighting.RT.TraceTriangles) {
            Settings.Internal.VoxelizeTriangles = true;
        }
    }

    if (Settings.Lighting.Reflections.Mode == ReflectMode_WSR) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.Accumulation = true;

        if (Settings.Lighting.Reflections.ReflectTriangles) {
            Settings.Internal.VoxelizeTriangles = true;
        }
        else {
            Settings.Internal.VoxelizeBlockFaces = true;
        }
    }

    if (Settings.Lighting.LpvRsmEnabled) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.LPV = true;
    }

    // TODO: debug only
    //Settings.Internal.Accumulation = false;

    worldSettings.disableShade = true;
    worldSettings.ambientOcclusionLevel = 0.0;
    worldSettings.sunPathRotation = Settings.Sky.SunAngle;
    worldSettings.shadowMapResolution = Settings.Shadows.Resolution;
    worldSettings.renderStars = false;
    worldSettings.renderMoon = false;
    worldSettings.renderSun = false;
    // worldSettings.vignette = false;
    // worldSettings.clouds = false;

    defineGlobally1("EFFECT_VL_ENABLED");
    if (Settings.Internal.Accumulation) defineGlobally1("ACCUM_ENABLED");

    defineGlobally("SKY_SEA_LEVEL", Settings.Sky.SeaLevel.toString());
    defineGlobally("SKY_FOG_DENSITY", Settings.Sky.FogDensity);
    if (Settings.Sky.FogNoise) defineGlobally1("SKY_FOG_NOISE");

    if (Settings.Water.Waves) {
        defineGlobally1("WATER_WAVES_ENABLED");
        
        if (Settings.Water.Tessellation) {
            defineGlobally1("WATER_TESSELLATION_ENABLED");
            defineGlobally("WATER_TESSELLATION_LEVEL", Settings.Water.Tessellation_Level.toString());
        }
    }

    if (Settings.Shadows.Enabled) defineGlobally1("SHADOWS_ENABLED");
    if (Settings.Shadows.CloudsEnabled) defineGlobally1("SHADOWS_CLOUD_ENABLED");
    if (Settings.Shadows.SS_Fallback) defineGlobally1("SHADOW_SCREEN");
    defineGlobally("SHADOW_RESOLUTION", Settings.Shadows.Resolution.toString());

    defineGlobally("MATERIAL_FORMAT", Settings.Material.Format);
    if (Settings.Material.Parallax.Enabled) {
        defineGlobally1("MATERIAL_PARALLAX_ENABLED");
        defineGlobally("MATERIAL_PARALLAX_DEPTH", Settings.Material.Parallax.Depth.toString());
        defineGlobally("MATERIAL_PARALLAX_SAMPLES", Settings.Material.Parallax.Samples.toString());
        if (Settings.Material.Parallax.Sharp) defineGlobally1("MATERIAL_PARALLAX_SHARP");
        if (Settings.Material.Parallax.DepthWrite) defineGlobally1("MATERIAL_PARALLAX_DEPTHWRITE");
    }
    defineGlobally("EMISSION_BRIGHTNESS", Settings.Material.EmissionBrightness.toString());
    if (Settings.Material.FancyLava) {
        defineGlobally1("FANCY_LAVA");
        defineGlobally("FANCY_LAVA_RES", Settings.Material.FancyLavaRes.toString());
    }

    defineGlobally("LIGHTING_MODE", Settings.Lighting.Mode.toString());
    //defineGlobally("LIGHTING_VL_RES", Settings.Lighting.VolumetricResolution.toString());

    defineGlobally("LIGHTING_REFLECT_MODE", Settings.Lighting.Reflections.Mode.toString());
    defineGlobally("LIGHTING_REFLECT_MAXSTEP", Settings.Lighting.Reflections.MaxStepCount.toString())
    if (Settings.Lighting.Reflections.Noise) defineGlobally1("MATERIAL_ROUGH_REFLECT_NOISE");
    if (Settings.Lighting.Reflections.Mode == ReflectMode_WSR) {
        if (Settings.Lighting.Reflections.ReflectTriangles) defineGlobally1("LIGHTING_REFLECT_TRIANGLE");
    }

    if (Settings.Internal.Voxelization) {
        defineGlobally1("VOXEL_ENABLED");
        defineGlobally("VOXEL_SIZE", Settings.Voxel.Size.toString());
        defineGlobally("VOXEL_FRUSTUM_OFFSET", Settings.Voxel.Offset.toString());

        if (Settings.Lighting.Mode == LightMode_RT) {
            defineGlobally1("RT_ENABLED");
            defineGlobally("RT_MAX_SAMPLE_COUNT", `${Settings.Lighting.RT.MaxSampleCount}u`);
            defineGlobally("LIGHT_BIN_MAX", Settings.Voxel.MaxLightCount.toString());
            defineGlobally("LIGHT_BIN_SIZE", LIGHT_BIN_SIZE.toString());

            if (Settings.Lighting.RT.TraceTriangles) defineGlobally1("RT_TRI_ENABLED");
        }

        if (Settings.Internal.VoxelizeBlockFaces) {
            defineGlobally1("VOXEL_BLOCK_FACE");
        }

        if (Settings.Internal.VoxelizeTriangles) {
            defineGlobally1("VOXEL_TRI_ENABLED");
            defineGlobally("QUAD_BIN_MAX", Settings.Voxel.MaxTriangleCount.toString());
            defineGlobally("QUAD_BIN_SIZE", QUAD_BIN_SIZE.toString());
        }

        // if (Settings.Lighting.ReflectionMode == ReflectMode_WSR) defineGlobally("VOXEL_WSR_ENABLED", "1");

        if (Settings.Internal.LPV) {
            defineGlobally1("LPV_ENABLED");

            if (Settings.Lighting.LpvRsmEnabled)
                defineGlobally1("LPV_RSM_ENABLED");
        }
    }

    if (Settings.Effect.SSAO) defineGlobally1("EFFECT_SSAO_ENABLED");
    if (Settings.Effect.SSGI) defineGlobally1("EFFECT_SSGI_ENABLED");
    defineGlobally("EFFECT_SSGIAO_SAMPLES", Settings.Effect.SSGIAO_Samples)

    defineGlobally("POST_CONTRAST", Settings.Post.Contrast.toString());
    if (Settings.Post.TAA) defineGlobally1("EFFECT_TAA_ENABLED");

    defineGlobally("POST_EXPOSURE_MIN", Settings.Post.Exposure.Min.toString());
    defineGlobally("POST_EXPOSURE_MAX", Settings.Post.Exposure.Max.toString());
    defineGlobally("POST_EXPOSURE_SPEED", Settings.Post.Exposure.Speed.toString());

    if (Settings.Debug.Enabled) {
        defineGlobally("DEBUG_VIEW", Settings.Debug.View);
        defineGlobally("DEBUG_MATERIAL", Settings.Debug.Material);
        if (Settings.Debug.WhiteWorld) defineGlobally1("DEBUG_WHITE_WORLD");
        if (Settings.Debug.HISTOGRAM) defineGlobally1("DEBUG_HISTOGRAM");
        if (Settings.Debug.RT) defineGlobally1("DEBUG_RT");
    }

    return Settings;
}


export function setupShader() {
    print("Setting up shader");

    const Settings = setupSettings();

    setLightColor("campfire", 243, 152, 73, 255);
    setLightColor("candle", 245, 127, 68, 255);
    setLightColor("cave_vines", 243, 133, 59, 255);
    setLightColor("cave_vines_plant", 243, 133, 59, 255);
    setLightColor("glow_lichen", 107, 238, 172, 255);
    setLightColor("lantern", 243, 158, 73, 255);
    setLightColor("lava", 193, 100, 38, 255);
    setLightColor("ochre_froglight", 223, 172, 71, 255);
    setLightColor("pearlescent_froglight", 224, 117, 232, 255);
    setLightColor("redstone_torch", 249, 50, 28, 255);
    setLightColor("redstone_wall_torch", 249, 50, 28, 255);
    setLightColor("soul_campfire", 40, 170, 235, 255);
    // setLightColor("soul_torch", 40, 170, 235, 255);
    setLightColor("torch", 243, 181, 73, 255);
    setLightColor("verdant_froglight", 99, 229, 60, 255);
    setLightColor("wall_torch", 243, 158, 73, 255);

    setLightColor("tinted_glass", 50, 38, 56, 255);
    setLightColor("white_stained_glass",      255, 255, 255, 255);
    setLightColor("white_stained_glass_pane", 255, 255, 255, 255);
    setLightColor("light_gray_stained_glass",      153, 153, 153, 255);
    setLightColor("light_gray_stained_glass_pane", 153, 153, 153, 255);
    setLightColor("gray_stained_glass",      76, 76, 76, 255);
    setLightColor("gray_stained_glass_pane", 76, 76, 76, 255);
    setLightColor("black_stained_glass",      25, 25, 25, 255);
    setLightColor("black_stained_glass_pane", 25, 25, 25, 255);
    setLightColor("brown_stained_glass",      102, 76, 51, 255);
    setLightColor("brown_stained_glass_pane", 102, 76, 51, 255);

    setLightColor("red_stained_glass",      153, 51, 51, 255);
    setLightColor("red_stained_glass_pane", 153, 51, 51, 255);
    setLightColor("orange_stained_glass",      216, 127, 51, 255);
    setLightColor("orange_stained_glass_pane", 216, 127, 51, 255);
    setLightColor("yellow_stained_glass",      229, 229, 51, 255);
    setLightColor("yellow_stained_glass_pane", 229, 229, 51, 255);
    setLightColor("lime_stained_glass",      127, 204, 25, 255);
    setLightColor("lime_stained_glass_pane", 127, 204, 25, 255);
    setLightColor("green_stained_glass",      102, 127, 51, 255);
    setLightColor("green_stained_glass_pane", 102, 127, 51, 255);
    setLightColor("cyan_stained_glass",      76, 127, 153, 255);
    setLightColor("cyan_stained_glass_pane", 76, 127, 153, 255);
    setLightColor("light_blue_stained_glass",      102, 153, 216, 255);
    setLightColor("light_blue_stained_glass_pane", 102, 153, 216, 255);
    setLightColor("blue_stained_glass",      51, 76, 178, 255);
    setLightColor("blue_stained_glass_pane", 51, 76, 178, 255);
    setLightColor("purple_stained_glass",      127, 63, 178, 255);
    setLightColor("purple_stained_glass_pane", 127, 63, 178, 255);
    setLightColor("magenta_stained_glass",      178, 76, 216, 255);
    setLightColor("magenta_stained_glass_pane", 178, 76, 216, 255);
    setLightColor("pink_stained_glass",      242, 127, 165, 255);
    setLightColor("pink_stained_glass_pane", 242, 127, 165, 255);

    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    const texFogNoise = new RawTexture("texFogNoise", "textures/fog.dat")
        .type(PixelType.UNSIGNED_BYTE)
        .format(Format.R8_SNORM)
        .width(256)
        .height(32)
        .depth(256)
        .clamp(false)
        .blur(true)
        .build();

    const texShadowColor = new ArrayTexture("texShadowColor")
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texShadowNormal = new ArrayTexture("texShadowNormal")
        .format(Format.RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texFinal = new Texture("texFinal")
        .imageName("imgFinal")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texFinalOpaque = new Texture("texFinalOpaque")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .mipmap(true)
        .build();

    const texFinalPrevious = new Texture("texFinalPrevious")
        .format(Format.RGBA16F)
        .clear(false)
        .mipmap(true)
        .build();

    const texClouds = new Texture("texClouds")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texParticles = new Texture("texParticles")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_Color = new Texture("texDeferredOpaque_Color")
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_TexNormal = new Texture("texDeferredOpaque_TexNormal")
        .format(Format.RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_Data = new Texture("texDeferredOpaque_Data")
        .format(Format.RGBA32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_Color = new Texture("texDeferredTrans_Color")
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_TexNormal = new Texture("texDeferredTrans_TexNormal")
        .format(Format.RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_Data = new Texture("texDeferredTrans_Data")
        .format(Format.RGBA32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    let texShadow: BuiltTexture | null = null;
    let texShadow_final: BuiltTexture | null = null;
    if (Settings.Shadows.Enabled) {
        texShadow = new Texture("texShadow")
            .format(Format.RGBA16F)
            .clear(false)
            .build();

        texShadow_final = new Texture("texShadow_final")
            .imageName("imgShadow_final")
            .format(Format.RGBA16F)
            .clear(false)
            .build();
    }

    const texVoxelBlock = new Texture("texVoxelBlock")
        .imageName("imgVoxelBlock")
        .format(Format.R32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(Settings.Voxel.Size)
        .height(Settings.Voxel.Size)
        .depth(Settings.Voxel.Size)
        .build();

    let texDiffuseRT: BuiltTexture | null = null;
    let texSpecularRT: BuiltTexture | null = null;
    if (Settings.Lighting.Mode == LightMode_RT || Settings.Lighting.Reflections.Mode == ReflectMode_WSR) {
        texDiffuseRT = new Texture("texDiffuseRT")
            // .imageName("imgDiffuseRT")
            .format(Format.RGB16F)
            // .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .build();

        texSpecularRT = new Texture("texSpecularRT")
            // .imageName("imgSpecularRT")
            .format(Format.RGB16F)
            // .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .build();
    }

    let texSSGIAO: BuiltTexture | null = null;
    let texSSGIAO_final: BuiltTexture | null = null;
    if (Settings.Effect.SSAO || Settings.Effect.SSGI) {
        texSSGIAO = new Texture("texSSGIAO")
            .format(Format.RGBA16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();

        texSSGIAO_final = new Texture("texSSGIAO_final")
            .imageName("imgSSGIAO_final")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    if (Settings.Internal.Accumulation) {
        new Texture("texAccumDiffuse_opaque")
            .imageName("imgAccumDiffuse_opaque")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumDiffuse_opaque_alt")
            .imageName("imgAccumDiffuse_opaque_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumDiffuse_translucent")
            .imageName("imgAccumDiffuse_translucent")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumDiffuse_translucent_alt")
            .imageName("imgAccumDiffuse_translucent_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumSpecular_opaque")
            .imageName("imgAccumSpecular_opaque")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumSpecular_opaque_alt")
            .imageName("imgAccumSpecular_opaque_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumSpecular_translucent")
            .imageName("imgAccumSpecular_translucent")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumSpecular_translucent_alt")
            .imageName("imgAccumSpecular_translucent_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumPosition_opaque")
            .imageName("imgAccumPosition_opaque")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumPosition_opaque_alt")
            .imageName("imgAccumPosition_opaque_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumPosition_translucent")
            .imageName("imgAccumPosition_translucent")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texAccumPosition_translucent_alt")
            .imageName("imgAccumPosition_translucent_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    const vlScale = Math.pow(2, Settings.Lighting.VolumetricResolution);
    const vlWidth = Math.ceil(screenWidth / vlScale);
    const vlHeight = Math.ceil(screenHeight / vlScale);

    const texScatterVL = new Texture("texScatterVL")
        .format(Format.RGB16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(false)
        .build();

    const texTransmitVL = new Texture("texTransmitVL")
        .format(Format.RGB16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(false)
        .build();

    let shLpvBuffer: BuiltBuffer | null = null;
    let shLpvBuffer_alt: BuiltBuffer | null = null;
    let shLpvRsmBuffer: BuiltBuffer | null = null;
    let shLpvRsmBuffer_alt: BuiltBuffer | null = null;
    if (Settings.Internal.LPV) {
        // f16vec4[3] * VoxelBufferSize^3
        const bufferSize = 8 * 3 * cubed(Settings.Voxel.Size);

        shLpvBuffer = new GPUBuffer(bufferSize)
            .clear(false)
            .build();

        shLpvBuffer_alt = new GPUBuffer(bufferSize)
            .clear(false)
            .build();

        if (Settings.Lighting.LpvRsmEnabled) {
            shLpvRsmBuffer = new GPUBuffer(bufferSize)
                .clear(false)
                .build();

            shLpvRsmBuffer_alt = new GPUBuffer(bufferSize)
                .clear(false)
                .build();
        }
    }

    const texHistogram = new Texture("texHistogram")
        .imageName("imgHistogram")
        .format(Format.R32UI)
        .width(256)
        .height(1)
        .clear(false)
        .build();

    if (Settings.Debug.HISTOGRAM) {
        const texHistogram_debug = new Texture("texHistogram_debug")
            .imageName("imgHistogram_debug")
            .format(Format.R32UI)
            .width(256)
            .height(1)
            .clear(false)
            .build();
    }

    const sceneBuffer = new GPUBuffer(1024)
        .clear(false)
        .build();

    let lightListBuffer: BuiltBuffer | null = null;
    let blockFaceBuffer: BuiltBuffer | null = null;
    let quadListBuffer: BuiltBuffer | null = null;
    if (Settings.Internal.Voxelization) {
        const lightBinSize = 4 * (1 + Settings.Voxel.MaxLightCount);
        const lightListBinCount = Math.ceil(Settings.Voxel.Size / LIGHT_BIN_SIZE);
        const lightListBufferSize = lightBinSize * cubed(lightListBinCount) + 4;
        print(`Light-List Buffer Size: ${lightListBufferSize.toLocaleString()}`);

        lightListBuffer = new GPUBuffer(lightListBufferSize)
            .clear(true) // TODO: clear with compute
            .build();

        if (Settings.Internal.VoxelizeBlockFaces) {
            const bufferSize = 6 * 16 * cubed(Settings.Voxel.Size);

            blockFaceBuffer = new GPUBuffer(bufferSize)
                .clear(true) // TODO: clear with compute
                .build();
        }

        if (Settings.Internal.VoxelizeTriangles) {
            const quadBinSize = 4 + 40*Settings.Voxel.MaxTriangleCount;
            const quadListBinCount = Math.ceil(Settings.Voxel.Size / QUAD_BIN_SIZE);
            const quadListBufferSize = quadBinSize * cubed(quadListBinCount) + 4;
            print(`Quad-List Buffer Size: ${quadListBufferSize.toLocaleString()}`);

            quadListBuffer = new GPUBuffer(quadListBufferSize)
                .clear(true) // TODO: clear with compute
                .build();
        }
    }

    registerShader(Stage.SCREEN_SETUP, new Compute("scene-setup")
        // .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-setup.csh")
        .ssbo(0, sceneBuffer)
        .build());

    registerShader(Stage.SCREEN_SETUP, new Compute("histogram-clear")
        // .barrier(true)
        .location("setup/histogram-clear.csh")
        .workGroups(1, 1, 1)
        .build());

    if (Settings.Internal.LPV) {
        registerShader(Stage.SCREEN_SETUP, new Compute("lpv-clear")
            // .barrier(true)
            .location("setup/lpv-clear.csh")
            .workGroups(8, 8, 8)
            .build());
    }

    registerShader(Stage.PRE_RENDER, new Compute("scene-prepare")
        // .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-prepare.csh")
        .ssbo(0, sceneBuffer)
        .ssbo(3, lightListBuffer)
        .ssbo(4, quadListBuffer)
        .build());

    // IMAGE_BIT | SSBO_BIT | UBO_BIT | FETCH_BIT
    registerBarrier(Stage.PRE_RENDER, new MemoryBarrier(SSBO_BIT));

    setupSky(sceneBuffer);

    registerBarrier(Stage.PRE_RENDER, new TextureBarrier());

    registerShader(Stage.PRE_RENDER, new Compute("scene-begin")
        // .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-begin.csh")
        .ssbo(0, sceneBuffer)
        .build());

    registerBarrier(Stage.PRE_RENDER, new MemoryBarrier(SSBO_BIT));

    function shadowShader(name: string, usage: ProgramUsage) : ObjectShader {
        return new ObjectShader(name, usage)
            .vertex("gbuffer/shadow.vsh")
            .geometry("gbuffer/shadow.gsh")
            .fragment("gbuffer/shadow.fsh")
            .ssbo(0, sceneBuffer)
            .ssbo(4, quadListBuffer)
            .target(0, texShadowColor)
            //.blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)
            .target(1, texShadowNormal);
            //.blendFunc(1, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO);
    }

    function shadowTerrainShader(name: string, usage: ProgramUsage) : ObjectShader {
        return shadowShader(name, usage)
            .ssbo(3, lightListBuffer)
            //.ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .define("RENDER_TERRAIN", "1");
    }

    function shadowEntityShader(name: string, usage: ProgramUsage) : ObjectShader {
        return shadowShader(name, usage)
            .define("RENDER_ENTITY", "1");
    }

    if (Settings.Shadows.Enabled) {
        registerShader(shadowShader("shadow", Usage.SHADOW).build());

        registerShader(shadowTerrainShader("shadow-terrain-solid", Usage.SHADOW_TERRAIN_SOLID).build());

        registerShader(shadowTerrainShader("shadow-terrain-cutout", Usage.SHADOW_TERRAIN_CUTOUT).build());

        registerShader(shadowTerrainShader("shadow-terrain-translucent", Usage.SHADOW_TERRAIN_TRANSLUCENT)
            .define("RENDER_TRANSLUCENT", "1")
            .build());

        registerShader(shadowEntityShader("shadow-entity-solid", Usage.SHADOW_ENTITY_SOLID).build());
        registerShader(shadowEntityShader("shadow-entity-cutout", Usage.SHADOW_ENTITY_CUTOUT).build());
        registerShader(shadowEntityShader("shadow-entity-translucent", Usage.SHADOW_ENTITY_TRANSLUCENT)
            .define("RENDER_TRANSLUCENT", "1")
            .build());
    }

    registerShader(new ObjectShader("sky-color", Usage.SKYBOX)
        .vertex("gbuffer/sky.vsh")
        .fragment("gbuffer/sky.fsh")
        .target(0, texFinalOpaque)
        // .blendFunc(0, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .build());

    // TODO: sky-textured?

    registerShader(new ObjectShader("clouds", Usage.CLOUDS)
        .vertex("gbuffer/clouds.vsh")
        .fragment("gbuffer/clouds.fsh")
        .target(0, texClouds)
        .ssbo(0, sceneBuffer)
        .build());

    function _mainShader(name: string, usage: ProgramUsage) : ObjectShader {
        return new ObjectShader(name, usage)
            .vertex("gbuffer/main.vsh")
            .fragment("gbuffer/main.fsh");
    }

    function mainShaderOpaque(name: string, usage: ProgramUsage) : ObjectShader {
        return _mainShader(name, usage)
            .target(0, texDeferredOpaque_Color)
            // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
            .target(1, texDeferredOpaque_TexNormal)
            // .blendFunc(1, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
            .target(2, texDeferredOpaque_Data);
            // .blendFunc(2, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
    }

    function mainShaderTranslucent(name: string, usage: ProgramUsage) : ObjectShader {
        return _mainShader(name, usage)
            .target(0, texDeferredTrans_Color)
            // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
            .target(1, texDeferredTrans_TexNormal)
            // .blendFunc(1, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
            .target(2, texDeferredTrans_Data)
            // .blendFunc(2, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
            .define("RENDER_TRANSLUCENT", "1");
    }

    registerShader(mainShaderOpaque("basic", Usage.BASIC).build());

    registerShader(mainShaderOpaque("terrain-solid", Usage.TERRAIN_SOLID)
        .define("RENDER_TERRAIN", "1")
        .build());

    registerShader(mainShaderOpaque("terrain-cutout", Usage.TERRAIN_CUTOUT)
        .define("RENDER_TERRAIN", "1")
        .build());

    const waterShader = mainShaderTranslucent("terrain-translucent", Usage.TERRAIN_TRANSLUCENT)
        .define("RENDER_TERRAIN", "1");

    if (Settings.Water.Waves && Settings.Water.Tessellation) {
        waterShader
            .control("gbuffer/main.tcs")
            .eval("gbuffer/main.tes");
    }

    registerShader(waterShader.build());

    registerShader(mainShaderOpaque("entity-solid", Usage.ENTITY_SOLID)
        .define("RENDER_ENTITY", "1")
        .build());

    registerShader(mainShaderOpaque("entity-cutout", Usage.ENTITY_CUTOUT)
        .define("RENDER_ENTITY", "1")
        .build());

    registerShader(mainShaderTranslucent("entity-translucent", Usage.ENTITY_TRANSLUCENT)
        .define("RENDER_ENTITY", "1")
        .build());

    registerShader(new ObjectShader("weather", Usage.WEATHER)
        .vertex("gbuffer/weather.vsh")
        .fragment("gbuffer/weather.fsh")
        .target(0, texParticles)
        .ssbo(0, sceneBuffer)
        .build());

    if (Settings.Internal.LPV) {
        const groupCount = Math.ceil(Settings.Voxel.Size / 8);

        const shader = new Compute("lpv-propagate")
            // .barrier(true)
            .location("composite/lpv-propagate.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);

        if (Settings.Lighting.LpvRsmEnabled) {
            shader
                .ssbo(3, shLpvRsmBuffer)
                .ssbo(4, shLpvRsmBuffer_alt);
        }

        registerShader(Stage.POST_RENDER, shader.build());

        //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));
    }

    if (Settings.Lighting.Mode == LightMode_RT) {
        const groupCount = Math.ceil(Settings.Voxel.Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("light-list")
            // .barrier(true)
            .location("composite/light-list.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .build());
    }

    if (Settings.Shadows.Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("shadow-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/shadow-opaque.fsh")
            .target(0, texShadow)
            .build());

        if (Settings.Shadows.Filter) {
            registerShader(Stage.POST_RENDER, new Compute("shadow-opaque-filter")
                // .barrier(true)
                .location("composite/shadow-opaque-filter.csh")
                .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                .build());

            //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        }
    }

    const texShadow_src = Settings.Shadows.Filter ? "texShadow_final" : "texShadow";

    if (Settings.Lighting.Mode == LightMode_RT || Settings.Lighting.Reflections.Mode == ReflectMode_WSR) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        if (Settings.Lighting.Reflections.Mode == ReflectMode_WSR)
            registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));
            //rtOpaqueShader.generateMips(texFinalPrevious);

        registerShader(Stage.POST_RENDER, new Composite("rt-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .define("TEX_DEFERRED_COLOR", "texDeferredOpaque_Color")
            .define("TEX_DEFERRED_DATA", "texDeferredOpaque_Data")
            .define("TEX_DEFERRED_NORMAL", "texDeferredOpaque_TexNormal")
            .define("TEX_DEPTH", "solidDepthTex")
            .define("TEX_SHADOW", texShadow_src)
            .build());
    }

    if (Settings.Effect.SSAO || Settings.Effect.SSGI) {
        registerShader(Stage.POST_RENDER, new Composite("ssgiao-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/ssgiao.fsh")
            .target(0, texSSGIAO)
            .build());

        registerShader(Stage.POST_RENDER, new Compute("ssgiao-filter-opaque")
            // .barrier(true)
            .location("composite/ssgiao-filter-opaque.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .build());
    }

    if (Settings.Internal.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute("accumulation-opaque")
            // .barrier(true)
            .location("composite/accumulation.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define("TEX_DEPTH", "solidDepthTex")
            .define("IMG_ACCUM_DIFFUSE", "imgAccumDiffuse_opaque")
            .define("IMG_ACCUM_SPECULAR", "imgAccumSpecular_opaque")
            .define("IMG_ACCUM_POSITION", "imgAccumPosition_opaque")
            .define("IMG_ACCUM_DIFFUSE_ALT", "imgAccumDiffuse_opaque_alt")
            .define("IMG_ACCUM_SPECULAR_ALT", "imgAccumSpecular_opaque_alt")
            .define("IMG_ACCUM_POSITION_ALT", "imgAccumPosition_opaque_alt")
            .define("TEX_ACCUM_DIFFUSE", "texAccumDiffuse_opaque")
            .define("TEX_ACCUM_SPECULAR", "texAccumSpecular_opaque")
            .define("TEX_ACCUM_POSITION", "texAccumPosition_opaque")
            .define("TEX_ACCUM_DIFFUSE_ALT", "texAccumDiffuse_opaque_alt")
            .define("TEX_ACCUM_SPECULAR_ALT", "texAccumSpecular_opaque_alt")
            .define("TEX_ACCUM_POSITION_ALT", "texAccumPosition_opaque_alt")
            .build());
    }

    registerShader(Stage.POST_RENDER, new Composite("volumetric-far")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/volumetric-far.fsh")
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        .ssbo(1, shLpvBuffer)
        .ssbo(2, shLpvBuffer_alt)
        .build());

    registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT | IMAGE_BIT));

    const compositeOpaqueShader = new Composite("composite-opaque")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-opaque.fsh")
        .target(0, texFinalOpaque)
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        .define("TEX_SHADOW", texShadow_src)
        .define("TEX_SSGIAO", "texSSGIAO_final");

    // if (Settings.Lighting.Reflections.Mode == ReflectMode_SSR)
    //     compositeOpaqueShader.generateMips(texFinalPrevious);

    if (Settings.Internal.LPV) {
        compositeOpaqueShader
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);
    }

    registerShader(Stage.POST_RENDER, compositeOpaqueShader.build());

    if (Settings.Lighting.Mode == LightMode_RT || Settings.Lighting.Reflections.Mode == ReflectMode_WSR) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        if (Settings.Lighting.Reflections.Mode == ReflectMode_WSR)
            registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));
            //rtTranslucentShader.generateMips(texFinalPrevious);

        registerShader(Stage.POST_RENDER, new Composite("rt-translucent")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .define("RENDER_TRANSLUCENT", "1")
            .define("TEX_DEFERRED_COLOR", "texDeferredTrans_Color")
            .define("TEX_DEFERRED_DATA", "texDeferredTrans_Data")
            .define("TEX_DEFERRED_NORMAL", "texDeferredTrans_TexNormal")
            .define("TEX_DEPTH", "mainDepthTex")
            .define("TEX_SHADOW", texShadow_src)
            .build());
    }

    if (Settings.Internal.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute("accumulation-translucent")
            // .barrier(true)
            .location("composite/accumulation.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define("RENDER_TRANSLUCENT", "1")
            .define("TEX_DEPTH", "mainDepthTex")
            .define("IMG_ACCUM_DIFFUSE", "imgAccumDiffuse_translucent")
            .define("IMG_ACCUM_SPECULAR", "imgAccumSpecular_translucent")
            .define("IMG_ACCUM_POSITION", "imgAccumPosition_translucent")
            .define("IMG_ACCUM_DIFFUSE_ALT", "imgAccumDiffuse_translucent_alt")
            .define("IMG_ACCUM_SPECULAR_ALT", "imgAccumSpecular_translucent_alt")
            .define("IMG_ACCUM_POSITION_ALT", "imgAccumPosition_translucent_alt")
            .define("TEX_ACCUM_DIFFUSE", "texAccumDiffuse_translucent")
            .define("TEX_ACCUM_SPECULAR", "texAccumSpecular_translucent")
            .define("TEX_ACCUM_POSITION", "texAccumPosition_translucent")
            .define("TEX_ACCUM_DIFFUSE_ALT", "texAccumDiffuse_translucent_alt")
            .define("TEX_ACCUM_SPECULAR_ALT", "texAccumSpecular_translucent_alt")
            .define("TEX_ACCUM_POSITION_ALT", "texAccumPosition_translucent_alt")
            .build());
    }

    registerShader(Stage.POST_RENDER, new Composite("volumetric-near")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/volumetric-near.fsh")
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        .ssbo(1, shLpvBuffer)
        .ssbo(2, shLpvBuffer_alt)
        .build());

    registerShader(Stage.POST_RENDER, new GenerateMips(texFinalOpaque));

    registerShader(Stage.POST_RENDER, new Composite("composite-translucent")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-translucent.fsh")
        .target(0, texFinal)
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        // .generateMips(texFinalOpaque)
        .build());

    if (Settings.Post.TAA) {
        registerShader(Stage.POST_RENDER, new Composite("copy-TAA")
            .vertex("shared/bufferless.vsh")
            .fragment("shared/copy.fsh")
            .define("TEX_SRC", "texFinal")
            .target(0, texFinalOpaque)
            .build());

        registerShader(Stage.POST_RENDER, new Composite("TAA")
            .vertex("shared/bufferless.vsh")
            .fragment("post/taa.fsh")
            .target(0, texFinal)
            .target(1, texFinalPrevious)
            .define("TEX_SRC", "texFinalOpaque")
            .build());
    }
    else {
        registerShader(Stage.POST_RENDER, new Composite("copy-prev")
            .vertex("shared/bufferless.vsh")
            .fragment("shared/copy.fsh")
            .define("TEX_SRC", "texFinal")
            .target(0, texFinalPrevious)
            .build());
    }

    registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));

    registerShader(Stage.POST_RENDER, new Composite("blur-near")
        .vertex("shared/bufferless.vsh")
        .fragment("post/blur-near.fsh")
        .target(0, texFinal)
        .define("TEX_SRC", "texFinalPrevious")
        //.generateMips(texFinalPrevious)
        .build());

    registerShader(Stage.POST_RENDER, new Compute("histogram")
        // .barrier(true)
        .location("post/histogram.csh")
        .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        .build());

    registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));

    registerShader(Stage.POST_RENDER, new Compute("exposure")
        .workGroups(1, 1, 1)
        .location("post/exposure.csh")
        .ssbo(0, sceneBuffer)
        .build());

    if (Settings.Effect.Bloom)
        setupBloom(texFinal);

    registerShader(Stage.POST_RENDER, new Composite("tonemap")
        .vertex("shared/bufferless.vsh")
        .fragment("post/tonemap.fsh")
        .ssbo(0, sceneBuffer)
        .target(0, texFinal)
        .build());

    if (Settings.Debug.Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("debug")
            .vertex("shared/bufferless.vsh")
            .fragment("post/debug.fsh")
            .target(0, texFinal)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .define("TEX_SHADOW", texShadow_src)
            .define("TEX_SSGIAO", "texSSGIAO_final")
            .build());
    }

    setCombinationPass(new CombinationPass("post/final.fsh").build());
}

export function setupFrame(state : WorldState) {
    worldSettings.sunPathRotation = getIntSetting("SKY_SUN_ANGLE");

    // if (isKeyDown(Keys.G)) testVal += 0.07;
    // if (isKeyDown(Keys.F)) testVal -= 0.07;
    // TEST_UBO.setFloat(0, testVal);
    //
    // TEST_UBO.finishFrame();
}

function setupSky(sceneBuffer) {
    const texSkyTransmit = new Texture("texSkyTransmit")
        .format(Format.RGB16F)
        .clear(false)
        .width(256)
        .height(64)
        .build();

    const texSkyMultiScatter = new Texture("texSkyMultiScatter")
        .format(Format.RGB16F)
        .clear(false)
        .width(32)
        .height(32)
        .build();

    const texSkyView = new Texture("texSkyView")
        .format(Format.RGB16F)
        .clear(false)
        .width(256)
        .height(256)
        .build();

    const texSkyIrradiance = new Texture("texSkyIrradiance")
        .format(Format.RGB16F)
        .clear(false)
        .width(32)
        .height(32)
        .build();

    registerShader(Stage.SCREEN_SETUP, new Composite("sky-transmit")
        .vertex("shared/bufferless.vsh")
        .fragment("setup/sky_transmit.fsh")
        .target(0, texSkyTransmit)
        .build())

    registerShader(Stage.SCREEN_SETUP, new Composite("sky-multi-scatter")
        .vertex("shared/bufferless.vsh")
        .fragment("setup/sky_multi_scatter.fsh")
        .target(0, texSkyMultiScatter)
        .build())

    registerShader(Stage.PRE_RENDER, new Composite("sky-view")
        .vertex("shared/bufferless.vsh")
        .fragment("setup/sky_view.fsh")
        .target(0, texSkyView)
        .ssbo(0, sceneBuffer)
        .build())

    registerShader(Stage.PRE_RENDER, new Composite("sky-irradiance")
        .vertex("shared/bufferless.vsh")
        .fragment("setup/sky_irradiance.fsh")
        .target(0, texSkyIrradiance)
        .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
        .ssbo(0, sceneBuffer)
        .build())
}

function setupBloom(texFinal) {
    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    const texBloom = new Texture("texBloom")
        .format(Format.RGB16F)
        .width(screenWidth_half)
        .height(screenHeight_half)
        .mipmap(true)
        .clear(false)
        .build();

    for (let i = 0; i < maxLod; i++) {
        let texSrc = i == 0
            ? "texFinal"
            : "texBloom"

        registerShader(Stage.POST_RENDER, new Composite(`bloom-down-${i}`)
            .vertex("shared/bufferless.vsh")
            .fragment("post/bloom/down.fsh")
            .target(0, texBloom, i)
            .define("TEX_SRC", texSrc)
            .define("TEX_SCALE", Math.pow(2, i).toString())
            .define("BLOOM_INDEX", i.toString())
            .define("MIP_INDEX", Math.max(i-1, 0).toString())
            .build());
    }

    for (let i = maxLod-1; i >= 0; i--) {
        const shader = new Composite(`bloom-up-${i}`)
            .vertex("shared/bufferless.vsh")
            .fragment("post/bloom/up.fsh")
            .define("TEX_SCALE", Math.pow(2, i+1).toString())
            .define("BLOOM_INDEX", i.toString())
            .define("MIP_INDEX", i.toString());

        if (i == 0) shader.target(0, texFinal);
        else shader.target(0, texBloom, i-1);

        shader.blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE);

        registerShader(Stage.POST_RENDER, shader.build());
    }
}

function defineGlobally1(name: string) {defineGlobally(name, "1");}

function cubed(x) {return x*x*x;}
