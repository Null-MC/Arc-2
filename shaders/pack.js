const FEATURE = {
    Accumulation: false,
    RT_ENABLED: false,
    RT_TRI_ENABLED: false,
    VL: true,
};

const DEBUG = false;
const DEBUG_SSGIAO = false;
const DEBUG_HISTOGRAM = false;
const LIGHT_BIN_SIZE = 8;
const TRIANGLE_BIN_SIZE = 4;


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
            SSR: getBoolSetting("MATERIAL_SSR_ENABLED"),
            SSR_Noise: getBoolSetting("MATERIAL_ROUGH_REFLECT_NOISE"),
        },
        Voxel: {
            Size: parseInt(getStringSetting("VOXEL_SIZE")),
            Offset: parseFloat(getStringSetting("VOXEL_FRUSTUM_OFFSET")),
            MaxLightCount: 64,
            MaxTriangleCount: 256,
            LPV: {
                Enabled: getBoolSetting("LPV_ENABLED"),
                RSM_Enabled: getBoolSetting("LPV_RSM_ENABLED"),
            },
        },
        Effect: {
            SSAO: getBoolSetting("EFFECT_SSAO_ENABLED"),
            SSGI: getBoolSetting("EFFECT_SSGI_ENABLED"),
        },
        Post: {
            Bloom: getBoolSetting("POST_BLOOM_ENABLED"),
            TAA: getBoolSetting("EFFECT_TAA_ENABLED"),
        },
    };

    worldSettings.disableShade = true;
    worldSettings.ambientOcclusionLevel = 0.0;
    worldSettings.sunPathRotation = Settings.Sky.SunAngle;
    worldSettings.shadowMapResolution = 1024;
    worldSettings.vignette = false;
    worldSettings.clouds = false;
    worldSettings.stars = false;
    worldSettings.moon = false;
    worldSettings.sun = false;

    if (FEATURE.VL) defineGlobally("EFFECT_VL_ENABLED", "1");
    if (FEATURE.RT_ENABLED) defineGlobally("RT_ENABLED", "1");
    if (FEATURE.RT_TRI_ENABLED) defineGlobally("RT_TRI_ENABLED", "1");
    if (FEATURE.Accumulation) defineGlobally("ACCUM_ENABLED", "1");

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
    if (Settings.Material.SSR) defineGlobally("MATERIAL_SSR_ENABLED", "1");
    if (Settings.Material.SSR_Noise) defineGlobally("MATERIAL_ROUGH_REFLECT_NOISE", "1");

    defineGlobally("VOXEL_SIZE", Settings.Voxel.Size.toString());
    defineGlobally("VOXEL_FRUSTUM_OFFSET", Settings.Voxel.Offset.toString());
    defineGlobally("LIGHT_BIN_MAX", Settings.Voxel.MaxLightCount.toString());
    defineGlobally("LIGHT_BIN_SIZE", LIGHT_BIN_SIZE.toString());
    defineGlobally("TRIANGLE_BIN_MAX", Settings.Voxel.MaxTriangleCount.toString());
    defineGlobally("TRIANGLE_BIN_SIZE", TRIANGLE_BIN_SIZE.toString());

    if (Settings.Voxel.LPV.Enabled) {
        defineGlobally("LPV_ENABLED", "1");

        if (Settings.Voxel.LPV.RSM_Enabled) {
            defineGlobally("LPV_RSM_ENABLED", "1");
        }
    }

    if (Settings.Post.TAA) defineGlobally("EFFECT_TAA_ENABLED", "1");

    if (DEBUG_SSGIAO) defineGlobally("DEBUG_SSGIAO", "1");
    if (DEBUG_HISTOGRAM) defineGlobally("DEBUG_HISTOGRAM", "1");

    return Settings;
}

function setupSky(sceneBuffer) {
    const texSkyTransmit = new Texture("texSkyTransmit")
        .format(RGB16F)
        .clear(false)
        .width(256)
        .height(64)
        .build();

    const texSkyMultiScatter = new Texture("texSkyMultiScatter")
        .format(RGB16F)
        .clear(false)
        .width(32)
        .height(32)
        .build();

    const texSkyView = new Texture("texSkyView")
        .format(RGB16F)
        .clear(false)
        .width(256)
        .height(256)
        .build();

    const texSkyIrradiance = new Texture("texSkyIrradiance")
        .format(RGB16F)
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
    let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    const texBloom = new Texture("texBloom")
        .format(RGB16F)
        .width(Math.ceil(screenWidth / 2.0))
        .height(Math.ceil(screenHeight / 2.0))
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

    registerUniforms("shadowLightPosition",
        "fogColor",
        "fogStart",
        "fogEnd",
        "skyColor",
        // "cloudHeight",
        "isEyeInWater",
        "eyeBrightness",
        "cameraPos",
        "lastCameraPos",
        "screenSize",
        "frameTime",
        "frameCounter",
        "worldTime",
        "dayProgression",
        "timeCounter",
        "rainStrength",
        "nearPlane",
        "farPlane",
        "renderDistance",
        "playerModelView",
        "lastPlayerModelView",
        "playerModelViewInverse",
        "playerProjection",
        "lastPlayerProjection",
        "playerProjectionInverse",
        "sunPosition",
        "shadowModelView",
        // "shadowModelViewInverse",
        "shadowProjection",
        "shadowProjectionSize",
        "cascadeSize",
        "guiHidden");

    finalizeUniforms();

    const texFogNoise = new RawTexture("texFogNoise", "textures/fog.dat")
        .type(PixelType.UNSIGNED_BYTE)
        .format(R8_SNORM)
        .width(256)
        .height(32)
        .depth(256)
        .clamp(false)
        .blur(true)
        .build();

    const texShadowColor = new ArrayTexture("texShadowColor")
        .format(RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texShadowNormal = new ArrayTexture("texShadowNormal")
        .format(RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texFinal = new Texture("texFinal")
        .imageName("imgFinal")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texFinalOpaque = new Texture("texFinalOpaque")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .mipmap(true)
        .build();

    const texFinalPrevious = new Texture("texFinalPrevious")
        .format(RGBA16F)
        .clear(false)
        .mipmap(true)
        .build();

    const texClouds = new Texture("texClouds")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texParticles = new Texture("texParticles")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_Color = new Texture("texDeferredOpaque_Color")
        .format(RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_TexNormal = new Texture("texDeferredOpaque_TexNormal")
        .format(RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredOpaque_Data = new Texture("texDeferredOpaque_Data")
        .format(RGBA32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_Color = new Texture("texDeferredTrans_Color")
        .format(RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_TexNormal = new Texture("texDeferredTrans_TexNormal")
        .format(RGB8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_Data = new Texture("texDeferredTrans_Data")
        .format(RGBA32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    let texShadow = null;
    let texShadow_final = null;
    if (Settings.Shadows.Enabled) {
        texShadow = new Texture("texShadow")
            .format(RGBA16F)
            .clear(false)
            .build();

        texShadow_final = new Texture("texShadow_final")
            .imageName("imgShadow_final")
            .format(RGBA16F)
            .clear(false)
            .build();
    }

    const texVoxelBlock = new Texture("texVoxelBlock")
        .imageName("imgVoxelBlock")
        .format(R32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(Settings.Voxel.Size)
        .height(Settings.Voxel.Size)
        .depth(Settings.Voxel.Size)
        .build();

    let texDiffuseRT = null;
    if (FEATURE.RT_ENABLED) {
        texDiffuseRT = new Texture("texDiffuseRT")
            // .imageName("imgRT")
            .format(RGB16F)
            // .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(Math.ceil(screenWidth / 2.0))
            .height(Math.ceil(screenHeight / 2.0))
            .build();
    }

    let texSSGIAO = null;
    let texSSGIAO_final = null;
    if (Settings.Effect.SSAO || Settings.Effect.SSGI) {
        texSSGIAO = new Texture("texSSGIAO")
            .format(RGBA16F)
            .width(Math.ceil(screenWidth / 2.0))
            .height(Math.ceil(screenHeight / 2.0))
            .clear(false)
            .build();

        texSSGIAO_final = new Texture("texSSGIAO_final")
            .imageName("imgSSGIAO_final")
            .format(RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    let texDiffuseAccum = null;
    let texDiffuseAccum_alt = null;
    let texDiffuseAccumPos = null;
    let texDiffuseAccumPos_alt = null;
    if (FEATURE.Accumulation) {
        texDiffuseAccum = new Texture("texDiffuseAccum")
            .imageName("imgDiffuseAccum")
            .format(RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccum_alt = new Texture("texDiffuseAccum_alt")
            .imageName("imgDiffuseAccum_alt")
            .format(RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccumPos = new Texture("texDiffuseAccumPos")
            .imageName("imgDiffuseAccumPos")
            .format(RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texDiffuseAccumPos_alt = new Texture("texDiffuseAccumPos_alt")
            .imageName("imgDiffuseAccumPos_alt")
            .format(RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    let texScatterVL = null;
    let texTransmitVL = null;
    if (FEATURE.VL) {
        texScatterVL = new Texture("texScatterVL")
            .format(RGB16F)
            .width(Math.ceil(screenWidth / 2.0))
            .height(Math.ceil(screenHeight / 2.0))
            .clear(false)
            .build();

        texTransmitVL = new Texture("texTransmitVL")
            .format(RGB16F)
            .width(Math.ceil(screenWidth / 2.0))
            .height(Math.ceil(screenHeight / 2.0))
            .clear(false)
            .build();
    }

    let shLpvBuffer = null;
    let shLpvBuffer_alt = null;
    let shLpvRsmBuffer = null;
    let shLpvRsmBuffer_alt = null;
    if (Settings.Voxel.LPV.Enabled) {
        // f16vec4[8] * Band[3] * VoxelBufferSize^3
        const bufferSize = 8 * 3 * (Settings.Voxel.Size*Settings.Voxel.Size*Settings.Voxel.Size);

        shLpvBuffer = new Buffer(bufferSize)
            .clear(false)
            .build();

        shLpvBuffer_alt = new Buffer(bufferSize)
            .clear(false)
            .build();

        if (Settings.Voxel.LPV.RSM_Enabled) {
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
        .format(R32UI)
        .width(256)
        .height(1)
        .clear(false)
        .build();

    if (DEBUG_HISTOGRAM) {
        const texHistogram_debug = new Texture("texHistogram_debug")
            .imageName("imgHistogram_debug")
            .format(R32UI)
            .width(256)
            .height(1)
            .clear(false)
            .build();
    }

    const sceneBuffer = new Buffer(1024)
        .clear(false)
        .build();

    let lightListBuffer = null;
    let triangleListBuffer = null;
    if (FEATURE.RT_ENABLED) {
        const lightBinSize = 4 * (1 + Settings.Voxel.MaxLightCount);
        const lightListBinCount = Math.ceil(Settings.Voxel.Size / LIGHT_BIN_SIZE);
        const lightListBufferSize = lightBinSize * lightListBinCount*lightListBinCount*lightListBinCount + 4;
        print(`Light-List Buffer Size: ${lightListBufferSize.toLocaleString()}`);

        lightListBuffer = new Buffer(lightListBufferSize)
            .clear(true) // TODO: clear with compute
            .build();

        if (FEATURE.RT_TRI_ENABLED) {
            const triangleBinSize = 4 + 32*Settings.Voxel.MaxTriangleCount;
            const triangleListBinCount = Math.ceil(Settings.Voxel.Size / TRIANGLE_BIN_SIZE);
            const triangleListBufferSize = triangleBinSize * triangleListBinCount*triangleListBinCount*triangleListBinCount + 4;
            print(`Triangle-List Buffer Size: ${triangleListBufferSize.toLocaleString()}`);

            triangleListBuffer = new Buffer(triangleListBufferSize)
                .clear(true) // TODO: clear with compute
                .build();
        }
    }

    registerShader(Stage.SCREEN_SETUP, new Compute("scene-setup")
        .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-setup.csh")
        .ssbo(0, sceneBuffer)
        .build());

    registerShader(Stage.SCREEN_SETUP, new Compute("histogram-clear")
        .barrier(true)
        .location("setup/histogram-clear.csh")
        .workGroups(1, 1, 1)
        .build());

    if (Settings.Voxel.LPV.Enabled) {
        registerShader(Stage.SCREEN_SETUP, new Compute("lpv-clear")
            .barrier(true)
            .location("setup/lpv-clear.csh")
            .workGroups(8, 8, 8)
            .build());
    }

    registerShader(Stage.PRE_RENDER, new Compute("scene-prepare")
        .barrier(true)
        .workGroups(1, 1, 1)
        .location("setup/scene-prepare.csh")
        .ssbo(0, sceneBuffer)
        .ssbo(3, lightListBuffer)
        .ssbo(4, triangleListBuffer)
        .build());

    setupSky(sceneBuffer);

    registerShader(Stage.PRE_RENDER, new Compute("scene-begin")
        .barrier(true)
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

    if (Settings.Voxel.LPV.Enabled) {
        const groupCount = Math.ceil(Settings.Voxel.Size / 8);

        const shader = new Compute("lpv-propagate")
            .barrier(true)
            .location("composite/lpv-propagate.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);

        if (Settings.Voxel.LPV.RSM_Enabled) {
            shader
                .ssbo(3, shLpvRsmBuffer)
                .ssbo(4, shLpvRsmBuffer_alt);
        }

        registerShader(Stage.POST_RENDER, shader.build());
    }

    if (FEATURE.RT_ENABLED) {
        const groupCount = Math.ceil(Settings.Voxel.Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("light-list")
            .barrier(true)
            .location("composite/light-list.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .build());

        registerShader(Stage.POST_RENDER, new Composite("rt-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt-opaque.fsh")
            .target(0, texDiffuseRT)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .build());
    }

    if (Settings.Effect.SSAO || Settings.Effect.SSGI) {
        registerShader(Stage.POST_RENDER, new Composite("ssgiao-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/ssgiao.fsh")
            .target(0, texSSGIAO)
            .build());

        registerShader(Stage.POST_RENDER, new Compute("ssgiao-filter-opaque")
            .barrier(true)
            .location("composite/ssgiao-filter-opaque.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .build());
    }

    if (FEATURE.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute("diffuse-accum-opaque")
            .barrier(true)
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

    if (FEATURE.VL) {
        registerShader(Stage.POST_RENDER, new Composite("volumetric-far")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/volumetric-far.fsh")
            .target(0, texScatterVL)
            .target(1, texTransmitVL)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
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
                .barrier(true)
                .location("composite/shadow-filter-opaque.csh")
                .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                .build());
        }
    }

    const texShadow_src = Settings.Shadows.Filter ? "texShadow_final" : "texShadow";

    const compositeOpaqueShader = new Composite("composite-opaque")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-opaque.fsh")
        .target(0, texFinalOpaque)
        .ssbo(0, sceneBuffer)
        .generateMips(texFinalPrevious)
        .define("TEX_SHADOW", texShadow_src)
        .define("TEX_SSGIAO", "texSSGIAO_final");

    if (Settings.Voxel.LPV.Enabled) {
        compositeOpaqueShader
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);
    }

    registerShader(Stage.POST_RENDER, compositeOpaqueShader.build());

    if (FEATURE.VL) {
        registerShader(Stage.POST_RENDER, new Composite("volumetric-near")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/volumetric-near.fsh")
            .target(0, texScatterVL)
            .target(1, texTransmitVL)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .build());
    }

    registerShader(Stage.POST_RENDER, new Composite("composite-translucent")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-trans.fsh")
        .target(0, texFinal)
        .ssbo(0, sceneBuffer)
        .generateMips(texFinalOpaque)
        .build());

    if (Settings.Post.TAA) {
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
        .barrier(true)
        .location("post/histogram.csh")
        .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        .build());

    registerShader(Stage.POST_RENDER, new Compute("exposure")
        .barrier(true)
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

    if (DEBUG) {
        registerShader(Stage.POST_RENDER, new Composite("debug")
            .vertex("shared/bufferless.vsh")
            .fragment("post/debug.fsh")
            .target(0, texFinal)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, triangleListBuffer)
            .define("TEX_SSGIAO", "texSSGIAO_final")
            .build());
    }

    setCombinationPass(new CombinationPass("post/final.fsh").build());
}
