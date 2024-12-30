import './iris'

const LIGHT_BIN_SIZE = 8;
const TRIANGLE_BIN_SIZE = 2;

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
            SunAngle: parseInt(getStringSetting("SKY_SUN_ANGLE")),
            SeaLevel: parseInt(getStringSetting("SKY_SEA_LEVEL")),
        },
        Water: {
            Waves: getBoolSetting("WATER_WAVES_ENABLED"),
            Tessellation: getBoolSetting("WATER_TESSELLATION_ENABLED"),
            Tessellation_Level: parseInt(getStringSetting("WATER_TESSELLATION_LEVEL")),
        },
        Shadows: {
            Enabled: getBoolSetting("SHADOWS_ENABLED"),
            Filter: true,
            SS_Fallback: true,
        },
        Material: {
            Format: getStringSetting("MATERIAL_FORMAT"),
            Parallax: {
                Enabled: getBoolSetting("MATERIAL_PARALLAX_ENABLED"),
                Depth: parseInt(getStringSetting("MATERIAL_PARALLAX_DEPTH")),
                Samples: parseInt(getStringSetting("MATERIAL_PARALLAX_SAMPLES")),
                Sharp: getBoolSetting("MATERIAL_PARALLAX_SHARP"),
            },
        },
        Lighting: {
            Mode: parseInt(getStringSetting("LIGHTING_MODE")),
            ReflectionMode: parseInt(getStringSetting("LIGHTING_REFLECT_MODE")),
            ReflectionNoise: getBoolSetting("LIGHTING_REFLECT_NOISE"),
            TraceTriangles: getBoolSetting("LIGHTING_TRACE_TRIANGLE"),
            LpvRsmEnabled: getBoolSetting("LPV_RSM_ENABLED"),
            RT: {
                MaxSampleCount: parseInt(getStringSetting("RT_MAX_SAMPLE_COUNT")),
            },
        },
        Voxel: {
            Size: parseInt(getStringSetting("VOXEL_SIZE")),
            Offset: parseFloat(getStringSetting("VOXEL_FRUSTUM_OFFSET")),
            MaxLightCount: 64,
            MaxTriangleCount: 64,
        },
        Effect: {
            SSAO: getBoolSetting("EFFECT_SSAO_ENABLED"),
            SSGI: getBoolSetting("EFFECT_SSGI_ENABLED"),
        },
        Post: {
            Bloom: getBoolSetting("POST_BLOOM_ENABLED"),
            TAA: getBoolSetting("EFFECT_TAA_ENABLED"),
        },
        Debug: {
            Enabled: getBoolSetting("DEBUG_ENABLED"),
            SSGIAO: false,
            HISTOGRAM: false,
            RT: false,
        },
        Internal: {
            Accumulation: false,
            Voxelization: false,
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
    }

    if (Settings.Lighting.ReflectionMode == ReflectMode_WSR) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.VoxelizeTriangles = true;
        Settings.Internal.Accumulation = true;
    }

    if (Settings.Lighting.LpvRsmEnabled) {
        Settings.Internal.Voxelization = true;
        Settings.Internal.LPV = true;
    }

    worldSettings.disableShade = true;
    worldSettings.ambientOcclusionLevel = 0.0;
    worldSettings.sunPathRotation = Settings.Sky.SunAngle;
    worldSettings.shadowMapResolution = 1024;
    worldSettings.renderStars = false;
    worldSettings.renderMoon = false;
    worldSettings.renderSun = false;
    // worldSettings.vignette = false;
    // worldSettings.clouds = false;

    defineGlobally("EFFECT_VL_ENABLED", "1");
    if (Settings.Internal.Accumulation) defineGlobally("ACCUM_ENABLED", "1");

    defineGlobally("SKY_SEA_LEVEL", Settings.Sky.SeaLevel.toString());

    if (Settings.Effect.SSAO) defineGlobally("EFFECT_SSAO_ENABLED", "1");
    if (Settings.Effect.SSGI) defineGlobally("EFFECT_SSGI_ENABLED", "1");

    if (Settings.Water.Waves) {
        defineGlobally("WATER_WAVES_ENABLED", "1");
        
        if (Settings.Water.Tessellation) {
            defineGlobally("WATER_TESSELLATION_ENABLED", "1");
            defineGlobally("WATER_TESSELLATION_LEVEL", Settings.Water.Tessellation_Level.toString());
        }
    }

    if (Settings.Shadows.Enabled) defineGlobally("SHADOWS_ENABLED", "1");
    if (Settings.Shadows.SS_Fallback) defineGlobally("SHADOW_SCREEN", "1");

    defineGlobally("MATERIAL_FORMAT", Settings.Material.Format);
    if (Settings.Material.Parallax.Enabled) {
        defineGlobally("MATERIAL_PARALLAX_ENABLED", "1");
        defineGlobally("MATERIAL_PARALLAX_DEPTH", Settings.Material.Parallax.Depth.toString());
        defineGlobally("MATERIAL_PARALLAX_SAMPLES", Settings.Material.Parallax.Samples.toString());
        if (Settings.Material.Parallax.Sharp) defineGlobally("MATERIAL_PARALLAX_SHARP", "1");
    }

    defineGlobally("LIGHTING_MODE", Settings.Lighting.Mode.toString());
    defineGlobally("LIGHTING_REFLECT_MODE", Settings.Lighting.ReflectionMode.toString());
    if (Settings.Lighting.ReflectionNoise) defineGlobally("MATERIAL_ROUGH_REFLECT_NOISE", "1");

    if (Settings.Internal.Voxelization) {
        defineGlobally("VOXEL_ENABLED", "1");
        defineGlobally("VOXEL_SIZE", Settings.Voxel.Size.toString());
        defineGlobally("VOXEL_FRUSTUM_OFFSET", Settings.Voxel.Offset.toString());

        if (Settings.Lighting.Mode == LightMode_RT) {
            defineGlobally("RT_ENABLED", "1");
            defineGlobally("RT_MAX_SAMPLE_COUNT", `${Settings.Lighting.RT.MaxSampleCount}u`);
            defineGlobally("LIGHT_BIN_MAX", Settings.Voxel.MaxLightCount.toString());
            defineGlobally("LIGHT_BIN_SIZE", LIGHT_BIN_SIZE.toString());

            if (Settings.Lighting.TraceTriangles) defineGlobally("RT_TRI_ENABLED", "1")
        }

        if (Settings.Internal.VoxelizeTriangles) {
            defineGlobally("VOXEL_TRI_ENABLED", "1");
            defineGlobally("TRIANGLE_BIN_MAX", Settings.Voxel.MaxTriangleCount.toString());
            defineGlobally("TRIANGLE_BIN_SIZE", TRIANGLE_BIN_SIZE.toString());
        }

        // if (Settings.Lighting.ReflectionMode == ReflectMode_WSR) defineGlobally("VOXEL_WSR_ENABLED", "1");

        if (Settings.Internal.LPV) {
            defineGlobally("LPV_ENABLED", "1");

            if (Settings.Lighting.LpvRsmEnabled)
                defineGlobally("LPV_RSM_ENABLED", "1");
        }
    }

    if (Settings.Post.TAA) defineGlobally("EFFECT_TAA_ENABLED", "1");

    if (Settings.Debug.Enabled) {
        if (Settings.Debug.SSGIAO) defineGlobally("DEBUG_SSGIAO", "1");
        if (Settings.Debug.HISTOGRAM) defineGlobally("DEBUG_HISTOGRAM", "1");
        if (Settings.Debug.RT) defineGlobally("DEBUG_RT", "1");
    }

    return Settings;
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

function setupShader() {
    print("Setting up shader");

    const Settings = setupSettings();

    setLightColor("campfire", 243, 152, 73, 255);
    setLightColor("candle", 245, 127, 68, 255);
    setLightColor("lantern", 243, 158, 73, 255);
    setLightColor("torch", 243, 181, 73, 255);
    setLightColor("wall_torch", 243, 158, 73, 255);
    setLightColor("redstone_torch", 249, 50, 28, 255);
    setLightColor("pearlescent_froglight", 224, 117, 232, 255);
    setLightColor("ochre_froglight", 223, 172, 71, 255);
    setLightColor("verdant_froglight", 99, 229, 60, 255);
    setLightColor("glow_lichen", 107, 238, 172, 255);
    setLightColor("cave_vines", 243, 133, 59, 255);
    setLightColor("cave_vines_plant", 243, 133, 59, 255);
    setLightColor("soul_campfire", 40, 170, 235, 255);
    // setLightColor("soul_torch", 40, 170, 235, 255);

    setLightColor("red_stained_glass", 255, 0, 0, 255);
    setLightColor("red_stained_glass_pane", 255, 0, 0, 255);
    setLightColor("green_stained_glass", 0, 255, 0, 255);
    setLightColor("green_stained_glass_pane", 0, 255, 0, 255);
    setLightColor("lime_stained_glass", 102, 255, 0, 255);
    setLightColor("lime_stained_glass_pane", 102, 255, 0, 255);
    setLightColor("blue_stained_glass", 0, 0, 255, 255);
    setLightColor("blue_stained_glass_pane", 0, 0, 255, 255);

    registerUniforms(
        // "atlasSize",
        "cameraPos",
        "cascadeSize",
        // "cloudHeight",
        // "dayProgression",
        "eyeBrightness",
        "farPlane",
        "fogColor",
        "fogStart",
        "fogEnd",
        "frameTime",
        "frameCounter",
        "guiHidden",
        "isEyeInWater",
        "lastCameraPos",
        "lastPlayerProjection",
        "lastPlayerModelView",
        "nearPlane",
        "playerModelView",
        "playerModelViewInverse",
        "playerProjection",
        "playerProjectionInverse",
        "rainStrength",
        "renderDistance",
        "screenSize",
        "shadowLightPosition",
        "shadowModelView",
        // "shadowModelViewInverse",
        "shadowProjection",
        "shadowProjectionSize",
        "skyColor",
        "sunPosition",
        "timeCounter",
        "worldTime");

    finalizeUniforms();

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
    if (Settings.Lighting.Mode == LightMode_RT || Settings.Lighting.ReflectionMode == ReflectMode_WSR) {
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

    let texDiffuseAccum: BuiltTexture | null = null;
    let texDiffuseAccum_alt: BuiltTexture | null = null;
    let texSpecularAccum: BuiltTexture | null = null;
    let texSpecularAccum_alt: BuiltTexture | null = null;
    let texDiffuseAccumPos: BuiltTexture | null = null;
    let texDiffuseAccumPos_alt: BuiltTexture | null = null;
    if (Settings.Internal.Accumulation) {
        texDiffuseAccum = new Texture("texDiffuseAccum")
            .imageName("imgDiffuseAccum")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccum_alt = new Texture("texDiffuseAccum_alt")
            .imageName("imgDiffuseAccum_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texSpecularAccum = new Texture("texSpecularAccum")
            .imageName("imgSpecularAccum")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texSpecularAccum_alt = new Texture("texSpecularAccum_alt")
            .imageName("imgSpecularAccum_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccumPos = new Texture("texDiffuseAccumPos")
            .imageName("imgDiffuseAccumPos")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccumPos_alt = new Texture("texDiffuseAccumPos_alt")
            .imageName("imgDiffuseAccumPos_alt")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    const texScatterVL = new Texture("texScatterVL")
        .format(Format.RGB16F)
        .width(screenWidth_half)
        .height(screenHeight_half)
        .clear(false)
        .build();

    const texTransmitVL = new Texture("texTransmitVL")
        .format(Format.RGB16F)
        .width(screenWidth_half)
        .height(screenHeight_half)
        .clear(false)
        .build();

    let shLpvBuffer: BuiltBuffer | null = null;
    let shLpvBuffer_alt: BuiltBuffer | null = null;
    let shLpvRsmBuffer: BuiltBuffer | null = null;
    let shLpvRsmBuffer_alt: BuiltBuffer | null = null;
    if (Settings.Internal.LPV) {
        // f16vec4[3] * VoxelBufferSize^3
        const bufferSize = 8 * 3 * cubed(Settings.Voxel.Size);

        shLpvBuffer = new Buffer(bufferSize)
            .clear(false)
            .build();

        shLpvBuffer_alt = new Buffer(bufferSize)
            .clear(false)
            .build();

        if (Settings.Lighting.LpvRsmEnabled) {
            shLpvRsmBuffer = new Buffer(bufferSize)
                .clear(false)
                .build();

            shLpvRsmBuffer_alt = new Buffer(bufferSize)
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

    const sceneBuffer = new Buffer(1024)
        .clear(false)
        .build();

    let lightListBuffer: BuiltBuffer | null = null;
    let triangleListBuffer: BuiltBuffer | null = null;
    if (Settings.Internal.Voxelization) {
        const lightBinSize = 4 * (1 + Settings.Voxel.MaxLightCount);
        const lightListBinCount = Math.ceil(Settings.Voxel.Size / LIGHT_BIN_SIZE);
        const lightListBufferSize = lightBinSize * cubed(lightListBinCount) + 4;
        print(`Light-List Buffer Size: ${lightListBufferSize.toLocaleString()}`);

        lightListBuffer = new Buffer(lightListBufferSize)
            .clear(true) // TODO: clear with compute
            .build();

        if (Settings.Internal.VoxelizeTriangles) {
            const triangleBinSize = 4 + 44*Settings.Voxel.MaxTriangleCount;
            const triangleListBinCount = Math.ceil(Settings.Voxel.Size / TRIANGLE_BIN_SIZE);
            const triangleListBufferSize = triangleBinSize * cubed(triangleListBinCount) + 4;
            print(`Triangle-List Buffer Size: ${triangleListBufferSize.toLocaleString()}`);

            triangleListBuffer = new Buffer(triangleListBufferSize)
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
        .ssbo(4, triangleListBuffer)
        .build());

    setupSky(sceneBuffer);

    registerShader(Stage.PRE_RENDER, new Compute("scene-begin")
        // .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-begin.csh")
        .ssbo(0, sceneBuffer)
        .build());

    if (Settings.Shadows.Enabled) {
        registerShader(new ObjectShader("shadow", Usage.SHADOW)
            .vertex("gbuffer/shadow.vsh")
            .geometry("gbuffer/shadow.gsh")
            .fragment("gbuffer/shadow.fsh")
            .target(0, texShadowColor)
            // .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)
            .target(1, texShadowNormal)
            .build());

        registerShader(new ObjectShader("shadow-terrain-solid", Usage.SHADOW_TERRAIN_SOLID)
            .vertex("gbuffer/shadow.vsh")
            .geometry("gbuffer/shadow.gsh")
            .fragment("gbuffer/shadow.fsh")
            .target(0, texShadowColor)
            // .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)
            .target(1, texShadowNormal)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .define("RENDER_TERRAIN", "1")
            .build());

        registerShader(new ObjectShader("shadow-terrain-cutout", Usage.SHADOW_TERRAIN_CUTOUT)
            .vertex("gbuffer/shadow.vsh")
            .geometry("gbuffer/shadow.gsh")
            .fragment("gbuffer/shadow.fsh")
            .target(0, texShadowColor)
            // .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)
            .target(1, texShadowNormal)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .define("RENDER_TERRAIN", "1")
            .build());

        registerShader(new ObjectShader("shadow-terrain-translucent", Usage.SHADOW_TERRAIN_TRANSLUCENT)
            .vertex("gbuffer/shadow.vsh")
            .geometry("gbuffer/shadow.gsh")
            .fragment("gbuffer/shadow.fsh")
            .target(0, texShadowColor)
            // .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)
            .target(1, texShadowNormal)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .define("RENDER_TERRAIN", "1")
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

    registerShader(new ObjectShader("terrain", Usage.BASIC)
        .vertex("gbuffer/main.vsh")
        .fragment("gbuffer/main.fsh")
        .target(0, texDeferredOpaque_Color)
        // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
        .target(1, texDeferredOpaque_TexNormal)
        // .blendFunc(1, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .target(2, texDeferredOpaque_Data)
        // .blendFunc(2, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .build());

    const waterShader = new ObjectShader("water", Usage.TERRAIN_TRANSLUCENT)
        .vertex("gbuffer/main.vsh")
        .fragment("gbuffer/main.fsh")
        .define("RENDER_TRANSLUCENT", "1")
        .target(0, texDeferredTrans_Color)
        // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
        .target(1, texDeferredTrans_TexNormal)
        .target(2, texDeferredTrans_Data);
        // .blendFunc(2, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)

    if (Settings.Water.Waves && Settings.Water.Tessellation) {
        waterShader
            .control("gbuffer/main.tcs")
            .eval("gbuffer/main.tes");
    }

    registerShader(waterShader.build());

    registerShader(new ObjectShader("weather", Usage.WEATHER)
        .vertex("gbuffer/weather.vsh")
        .fragment("gbuffer/weather.fsh")
        .target(0, texParticles)
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
            registerShader(Stage.POST_RENDER, new Compute("shadow-filter-opaque")
                // .barrier(true)
                .location("composite/shadow-filter-opaque.csh")
                .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                .build());
        }
    }

    const texShadow_src = Settings.Shadows.Filter ? "texShadow_final" : "texShadow";

    if (Settings.Lighting.Mode == LightMode_RT || Settings.Lighting.ReflectionMode == ReflectMode_WSR) {
        const rtOpaqueShader = new Composite("rt-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt-opaque.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .define("TEX_SHADOW", texShadow_src);

        if (Settings.Lighting.ReflectionMode == ReflectMode_WSR)
            rtOpaqueShader.generateMips(texFinalPrevious);

        registerShader(Stage.POST_RENDER, rtOpaqueShader.build());
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
        registerShader(Stage.POST_RENDER, new Compute("diffuse-accum-opaque")
            // .barrier(true)
            .location("composite/diffuse-accum-opaque.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .build());

        // registerShader(Stage.POST_RENDER, new Composite("diffuse-accum-copy-prev")
        //     .vertex("shared/bufferless.vsh")
        //     .fragment("shared/copy.fsh")
        //     .target(0, texDiffuseAccumPrevious)
        //     .define("TEX_SRC", "texDiffuseAccum")
        //     .build());
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

    const compositeOpaqueShader = new Composite("composite-opaque")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-opaque.fsh")
        .target(0, texFinalOpaque)
        .ssbo(0, sceneBuffer)
        .ssbo(4, triangleListBuffer)
        .define("TEX_SHADOW", texShadow_src)
        .define("TEX_SSGIAO", "texSSGIAO_final");

    if (Settings.Lighting.ReflectionMode == ReflectMode_SSR)
        compositeOpaqueShader.generateMips(texFinalPrevious);

    if (Settings.Internal.LPV) {
        compositeOpaqueShader
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);
    }

    registerShader(Stage.POST_RENDER, compositeOpaqueShader.build());

    registerShader(Stage.POST_RENDER, new Composite("volumetric-near")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/volumetric-near.fsh")
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        .ssbo(1, shLpvBuffer)
        .ssbo(2, shLpvBuffer_alt)
        .build());

    registerShader(Stage.POST_RENDER, new Composite("composite-translucent")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-trans.fsh")
        .target(0, texFinal)
        .ssbo(0, sceneBuffer)
        .ssbo(4, triangleListBuffer)
        .generateMips(texFinalOpaque)
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

    registerShader(Stage.POST_RENDER, new Compute("histogram")
        // .barrier(true)
        .location("post/histogram.csh")
        .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        .build());

    registerShader(Stage.POST_RENDER, new Compute("exposure")
        // .barrier(true)
        .imageBarrier()
        .workGroups(1, 1, 1)
        .location("post/exposure.csh")
        .ssbo(0, sceneBuffer)
        .build());

    if (Settings.Post.Bloom)
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
            .ssbo(4, triangleListBuffer)
            .define("TEX_SHADOW", texShadow_src)
            .define("TEX_SSGIAO", "texSSGIAO_final")
            .build());
    }

    setCombinationPass(new CombinationPass("post/final.fsh").build());
}

function cubed(x) {return x*x*x;}
