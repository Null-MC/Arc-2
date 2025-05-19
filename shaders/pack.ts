import {BlockMap} from "./scripts/BlockMap";
import {setLightColorEx, StreamBufferBuilder} from "./scripts/helpers";
import {buildSettings, LightingModes, ReflectionModes, ShaderSettings} from "./scripts/settings";


const LIGHT_BIN_SIZE = 4;
const QUAD_BIN_SIZE = 2;

const Settings = new ShaderSettings();

const SceneSettingsBufferSize = 128;
let SceneSettingsBuffer: BuiltStreamingBuffer;
let BlockMappings: BlockMap;


function applySettings(settings) {
    const snapshot = settings.snapshot;

    worldSettings.disableShade = true;
    worldSettings.ambientOcclusionLevel = 0.0;
    worldSettings.sunPathRotation = settings.realtime.Sky_SunAngle;
    worldSettings.shadowMapResolution = snapshot.Shadow_Resolution;
    worldSettings.renderWaterOverlay = false;
    worldSettings.renderStars = false;
    worldSettings.renderMoon = false;
    worldSettings.renderSun = false;
    // worldSettings.vignette = false;
    // worldSettings.clouds = false;

    // TODO: fix hands later, for now just unbreak them
    worldSettings.mergedHandDepth = true;

    if (settings.Internal.VoxelizeBlocks)
        worldSettings.cascadeSafeZones[0] = snapshot.Voxel_Size / 2;

    defineGlobally1("EFFECT_VL_ENABLED");
    if (settings.Internal.Accumulation) defineGlobally1("ACCUM_ENABLED");

    if (snapshot.Sky_Clouds) defineGlobally1("SKY_CLOUDS_ENABLED");
    if (snapshot.Sky_FogNoise) defineGlobally1("SKY_FOG_NOISE");
    if (snapshot.Sky_Fog_CaveEnabled) defineGlobally1("FOG_CAVE_ENABLED");

    if (snapshot.Water_WaveEnabled) {
        defineGlobally1("WATER_WAVES_ENABLED");
        //defineGlobally("WATER_WAVES_DETAIL", snapshot.Water_WaveDetail.toString());

        if (snapshot.Water_Tessellation) {
            defineGlobally1("WATER_TESSELLATION_ENABLED");
            //defineGlobally("WATER_TESSELLATION_LEVEL", snapshot.Water_TessellationLevel.toString());
        }
    }

    if (snapshot.Shadow_Enabled) defineGlobally1("SHADOWS_ENABLED");
    if (snapshot.Shadow_CloudEnabled) defineGlobally1("SHADOWS_CLOUD_ENABLED");
    if (snapshot.Shadow_SS_Fallback) defineGlobally1("SHADOW_SCREEN");
    defineGlobally("SHADOW_RESOLUTION", snapshot.Shadow_Resolution);

    defineGlobally("MATERIAL_FORMAT", snapshot.Material_Format);
    defineGlobally("MATERIAL_NORMAL_FORMAT", snapshot.Material_NormalFormat);
    defineGlobally("MATERIAL_POROSITY_FORMAT", snapshot.Material_PorosityFormat);
    if (snapshot.Material_ParallaxEnabled) {
        defineGlobally1("MATERIAL_PARALLAX_ENABLED");
        defineGlobally("MATERIAL_PARALLAX_DEPTH", snapshot.Material_ParallaxDepth);
        defineGlobally("MATERIAL_PARALLAX_SAMPLES", snapshot.Material_ParallaxStepCount);
        if (snapshot.Material_ParallaxSharp) defineGlobally1("MATERIAL_PARALLAX_SHARP");
        if (snapshot.Material_ParallaxDepthWrite) defineGlobally1("MATERIAL_PARALLAX_DEPTHWRITE");
    }
    if (snapshot.Material_NormalSmooth) defineGlobally1("MATERIAL_NORMAL_SMOOTH");
    if (snapshot.Material_FancyLava) {
        defineGlobally1("FANCY_LAVA");
        defineGlobally("FANCY_LAVA_RES", snapshot.Material_FancyLavaResolution);
    }

    defineGlobally("LIGHTING_MODE", snapshot.Lighting_Mode);
    defineGlobally("LIGHTING_VL_RES", snapshot.Lighting_VolumetricResolution);

    defineGlobally("LIGHTING_REFLECT_MODE", snapshot.Lighting_ReflectionMode);
    defineGlobally("LIGHTING_REFLECT_MAXSTEP", snapshot.Lighting_ReflectionStepCount)
    if (snapshot.Lighting_ReflectionNoise) defineGlobally1("MATERIAL_ROUGH_REFLECT_NOISE");
    if (snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        if (snapshot.Lighting_ReflectionQuads) defineGlobally1("LIGHTING_REFLECT_TRIANGLE");
    }

    if (settings.Internal.VoxelizeBlocks) {
        defineGlobally1("VOXEL_ENABLED");
        defineGlobally("VOXEL_SIZE", snapshot.Voxel_Size);
        defineGlobally("VOXEL_FRUSTUM_OFFSET", snapshot.Voxel_Offset);

        if (snapshot.Voxel_UseProvided)
            defineGlobally1("VOXEL_PROVIDED");

        if (snapshot.Lighting_Mode == LightingModes.RayTraced) {
            defineGlobally1("RT_ENABLED");
            defineGlobally("RT_MAX_SAMPLE_COUNT", `${snapshot.Lighting_TraceSampleCount}u`);
            defineGlobally("RT_MAX_LIGHT_COUNT", snapshot.Lighting_TraceLightMax)
            //defineGlobally("LIGHT_BIN_MAX", snapshot.Voxel_MaxLightCount);
            defineGlobally("LIGHT_BIN_SIZE", LIGHT_BIN_SIZE);

            if (snapshot.Lighting_TraceQuads) defineGlobally1("RT_TRI_ENABLED");
        }

        if (settings.Internal.VoxelizeBlockFaces) {
            defineGlobally1("VOXEL_BLOCK_FACE");
        }

        if (settings.Internal.VoxelizeTriangles) {
            defineGlobally1("VOXEL_TRI_ENABLED");
            defineGlobally("QUAD_BIN_MAX", snapshot.Voxel_MaxQuadCount);
            defineGlobally("QUAD_BIN_SIZE", QUAD_BIN_SIZE);
        }

        if (() => parseInt(getStringSetting("LIGHTING_MODE")) == LightingModes.FloodFill)
            defineGlobally1("LPV_ENABLED");

        if (snapshot.Lighting_GI_Enabled) {
            defineGlobally1("LIGHTING_GI_ENABLED");

            if (snapshot.Lighting_GI_SkyLight)
                defineGlobally1("LIGHTING_GI_SKYLIGHT");
        }
    }

    if (snapshot.Effect_SSAO_Enabled) defineGlobally1("EFFECT_SSAO_ENABLED");
    defineGlobally("EFFECT_SSAO_SAMPLES", snapshot.Effect_SSAO_StepCount);

    if (snapshot.Effect_TAA_Enabled) defineGlobally1("EFFECT_TAA_ENABLED");

    if (snapshot.Debug_WhiteWorld) defineGlobally1("DEBUG_WHITE_WORLD");
    if (snapshot.Debug_Histogram) defineGlobally1("DEBUG_HISTOGRAM");
    if (snapshot.Debug_RT) defineGlobally1("DEBUG_RT");
    //if (snapshot.Debug_QuadLists) defineGlobally1("DEBUG_QUADS");

    if (settings.Internal.DebugEnabled) {
        defineGlobally("DEBUG_VIEW", snapshot.Debug_View);
        defineGlobally("DEBUG_MATERIAL", snapshot.Debug_Material);
        if (snapshot.Debug_Translucent) defineGlobally1("DEBUG_TRANSLUCENT");
    }
}

export function setupShader() {
    print("Setting up shader");

    BlockMappings = new BlockMap();
    BlockMappings.map('grass_block', 'BLOCK_GRASS');

    const snapshot = Settings.getStaticSnapshot();
    const realtime = Settings.getRealTimeSnapshot();
    const settings = buildSettings(snapshot, realtime);
    applySettings(settings);

    setLightColorEx("#362b21", "brown_mushroom");
    setLightColorEx("#f39849", "campfire");
    setLightColorEx("#935b2c", "cave_vines", "cave_vines_plant");
    setLightColorEx("#7f17a8", "crying_obsidian");
    setLightColorEx("#371559", "enchanting_table");
    setLightColorEx("#bea935", "firefly_bush");
    setLightColorEx("#5f9889", "glow_lichen");
    setLightColorEx("#d3b178", "glowstone");
    setLightColorEx("#f39e49", "lantern");
    setLightColorEx("#b8491c", "lava");
    setLightColorEx("#650a5e", "nether_portal");
    setLightColorEx("#dfac47", "ochre_froglight");
    setLightColorEx("#e075e8", "pearlescent_froglight");
    setLightColorEx("#f9321c", "redstone_torch", "redstone_wall_torch");
    setLightColorEx("#e0ba42", "redstone_lamp");
    setLightColorEx("#f9321c", "redstone_ore");
    setLightColorEx("#8bdff8", "sea_lantern");
    setLightColorEx("#28aaeb", "soul_torch", "soul_wall_torch", "soul_campfire");
    setLightColorEx("#f3b549", "torch", "wall_torch");
    setLightColorEx("#63e53c", "verdant_froglight");

    // setLightColorEx("#ff0000", "redstone_wall_torch");
    // setLightColorEx("#330000", "soul_wall_torch");

    setLightColorEx("#322638", "tinted_glass");
    setLightColorEx("#ffffff", "white_stained_glass", "white_stained_glass_pane");
    setLightColorEx("#999999", "light_gray_stained_glass", "light_gray_stained_glass_pane");
    setLightColorEx("#4c4c4c", "gray_stained_glass", "gray_stained_glass_pane");
    setLightColorEx("#191919", "black_stained_glass", "black_stained_glass_pane");
    setLightColorEx("#664c33", "brown_stained_glass", "brown_stained_glass_pane");
    setLightColorEx("#993333", "red_stained_glass", "red_stained_glass_pane");
    setLightColorEx("#d87f33", "orange_stained_glass", "orange_stained_glass_pane");
    setLightColorEx("#e5e533", "yellow_stained_glass", "yellow_stained_glass_pane");

    setLightColorEx("#7fcc19", "lime_stained_glass", "lime_stained_glass_pane");
    setLightColorEx("#667f33", "green_stained_glass", "green_stained_glass_pane");
    setLightColorEx("#4c7f99", "cyan_stained_glass", "cyan_stained_glass_pane");
    setLightColorEx("#6699d8", "light_blue_stained_glass", "light_blue_stained_glass_pane");
    setLightColorEx("#334cb2", "blue_stained_glass", "blue_stained_glass_pane");
    setLightColorEx("#7f3fb2", "purple_stained_glass", "purple_stained_glass_pane");
    setLightColorEx("#b24cd8", "magenta_stained_glass", "magenta_stained_glass_pane");
    setLightColorEx("#f27fa5", "pink_stained_glass", "pink_stained_glass_pane");

    if (snapshot.Lighting_ColorCandles) {
        setLightColorEx("#c07047", "candle");
        setLightColorEx("#ffffff", "white_candle");
        setLightColorEx("#bbbbbb", "light_gray_candle");
        setLightColorEx("#696969", "gray_candle");
        setLightColorEx("#1f1f1f", "black_candle");
        setLightColorEx("#8f5b35", "brown_candle");
        setLightColorEx("#b53129", "red_candle");
        setLightColorEx("#ff8118", "orange_candle");
        setLightColorEx("#ffcc4b", "yellow_candle");
        setLightColorEx("#7bc618", "lime_candle");
        setLightColorEx("#608116", "green_candle");
        setLightColorEx("#129e9d", "cyan_candle");
        setLightColorEx("#29a1d5", "light_blue_candle");
        setLightColorEx("#455abe", "blue_candle");
        setLightColorEx("#832cb4", "purple_candle");
        setLightColorEx("#bd3cb4", "magenta_candle");
        setLightColorEx("#f689ac", "pink_candle");
    }
    else {
        setLightColorEx("#c07047", "candle", "white_candle", "light_gray_candle", "gray_candle", "black_candle",
            "brown_candle", "red_candle", "orange_candle", "yellow_candle", "lime_candle", "green_candle", "cyan_candle",
            "light_blue_candle", "blue_candle", "purple_candle", "magenta_candle", "pink_candle");
    }

    //addTag(1, new NamespacedId("minecraft", "leaves"));

    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    SceneSettingsBuffer = new StreamingBuffer(SceneSettingsBufferSize).build();

    const texFogNoise = new RawTexture("texFogNoise", "textures/fog.dat")
        .type(PixelType.UNSIGNED_BYTE)
        .format(Format.R8_SNORM)
        .width(256)
        .height(32)
        .depth(256)
        .clamp(false)
        .blur(true)
        .build();

    const texBlueNoise = new RawTexture("texBlueNoise", "textures/blue_noise.png")
        .type(PixelType.UNSIGNED_BYTE)
        .format(Format.R8_SNORM)
        .width(512)
        .height(512)
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
        .format(Format.RGB16)
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
        .format(Format.RGB16)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_Data = new Texture("texDeferredTrans_Data")
        .format(Format.RGBA32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    let texShadow: BuiltTexture | null = null;
    let texShadow_final: BuiltTexture | null = null;
    if (snapshot.Shadow_Enabled) {
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

    if (settings.Internal.VoxelizeBlocks && !snapshot.Voxel_UseProvided) {
        new Texture("texVoxelBlock")
            .imageName("imgVoxelBlock")
            .format(Format.R32UI)
            .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(snapshot.Voxel_Size)
            .height(snapshot.Voxel_Size)
            .depth(snapshot.Voxel_Size)
            .build();
    }

    let texDiffuseRT: BuiltTexture | null = null;
    let texSpecularRT: BuiltTexture | null = null;
    if (snapshot.Lighting_Mode == LightingModes.RayTraced || snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
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

    let texSSAO: BuiltTexture | null = null;
    let texSSAO_final: BuiltTexture | null = null;
    if (snapshot.Effect_SSAO_Enabled) {
        texSSAO = new Texture("texSSAO")
            .format(Format.R16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();

        texSSAO_final = new Texture("texSSAO_final")
            .imageName("imgSSAO_final")
            .format(Format.R16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    if (settings.Internal.Accumulation) {
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

        if (snapshot.Effect_SSAO_Enabled) {
            new Texture("texAccumOcclusion_opaque")
                .imageName("imgAccumOcclusion_opaque")
                .format(Format.R16F)
                .width(screenWidth)
                .height(screenHeight)
                .clear(false)
                .build();

            new Texture("texAccumOcclusion_opaque_alt")
                .imageName("imgAccumOcclusion_opaque_alt")
                .format(Format.R16F)
                .width(screenWidth)
                .height(screenHeight)
                .clear(false)
                .build();
        }
    }

    const vlScale = Math.pow(2, snapshot.Lighting_VolumetricResolution);
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

    if (snapshot.Lighting_VolumetricResolution > 0) {
        new Texture("texScatterFinal")
            .imageName("imgScatterFinal")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        new Texture("texTransmitFinal")
            .imageName("imgTransmitFinal")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    let shLpvBuffer: BuiltBuffer | null = null;
    let shLpvBuffer_alt: BuiltBuffer | null = null;
    if (snapshot.Lighting_GI_Enabled) {
        // f16vec4[3] * VoxelBufferSize^3
        const bufferSize = 48 * cubed(snapshot.Voxel_Size);

        shLpvBuffer = new GPUBuffer(bufferSize)
            .clear(false)
            .build();

        shLpvBuffer_alt = new GPUBuffer(bufferSize)
            .clear(false)
            .build();
    }

    if (snapshot.Lighting_Mode == LightingModes.FloodFill) {
        const texFloodFill = new Texture("texFloodFill")
            .imageName("imgFloodFill")
            .format(Format.RGBA16F)
            .width(snapshot.Voxel_Size)
            .height(snapshot.Voxel_Size)
            .depth(snapshot.Voxel_Size)
            .clear(false)
            .build();

        const texFloodFill_alt = new Texture("texFloodFill_alt")
            .imageName("imgFloodFill_alt")
            .format(Format.RGBA16F)
            .width(snapshot.Voxel_Size)
            .height(snapshot.Voxel_Size)
            .depth(snapshot.Voxel_Size)
            .clear(false)
            .build();
    }

    const texHistogram = new Texture("texHistogram")
        .imageName("imgHistogram")
        .format(Format.R32UI)
        .width(256)
        .height(1)
        .clear(false)
        .build();

    if (snapshot.Debug_Histogram) {
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
    if (settings.Internal.VoxelizeBlocks) {
        const lightBinSize = 4 * (1 + snapshot.Lighting_TraceLightMax);
        const lightListBinCount = Math.ceil(snapshot.Voxel_Size / LIGHT_BIN_SIZE);
        const lightListBufferSize = lightBinSize * cubed(lightListBinCount) + 4;
        print(`Light-List Buffer Size: ${lightListBufferSize.toLocaleString()}`);

        lightListBuffer = new GPUBuffer(lightListBufferSize)
            .clear(true) // TODO: clear with compute
            .build();

        if (settings.Internal.VoxelizeBlockFaces) {
            const bufferSize = 6 * 8 * cubed(snapshot.Voxel_Size);

            blockFaceBuffer = new GPUBuffer(bufferSize)
                .clear(true) // TODO: clear with compute
                .build();
        }

        if (settings.Internal.VoxelizeTriangles) {
            const quadBinSize = 4 + 40*snapshot.Voxel_MaxQuadCount;
            const quadListBinCount = Math.ceil(snapshot.Voxel_Size / QUAD_BIN_SIZE);
            const quadListBufferSize = quadBinSize * cubed(quadListBinCount) + 4;
            print(`Quad-List Buffer Size: ${quadListBufferSize.toLocaleString()}`);

            quadListBuffer = new GPUBuffer(quadListBufferSize)
                .clear(true) // TODO: clear with compute
                .build();
        }
    }

    registerShader(Stage.SCREEN_SETUP, new Compute("scene-setup")
        .workGroups(1, 1, 1)
        .location("setup/scene-setup.csh")
        .ssbo(0, sceneBuffer)
        .build());

    registerShader(Stage.SCREEN_SETUP, new Compute("histogram-clear")
        .location("setup/histogram-clear.csh")
        .workGroups(1, 1, 1)
        .build());

    if (snapshot.Lighting_GI_Enabled) {
        registerShader(Stage.SCREEN_SETUP, new Compute("sh-gi-clear")
            .location("setup/sh-gi-clear.csh")
            .workGroups(8, 8, 8)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .build());
    }

    registerShader(Stage.PRE_RENDER, new Compute("scene-prepare")
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
            //.blendOff(0)
            .target(1, texShadowNormal)
            //.blendOff(1);
            .define("RENDER_SHADOW", "1");
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

    if (snapshot.Shadow_Enabled) {
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
        .ubo(0, SceneSettingsBuffer)
        .define("RENDER_TERRAIN", "1");

    if (snapshot.Water_WaveEnabled && snapshot.Water_Tessellation) {
        waterShader
            .control("gbuffer/main.tcs")
            .eval("gbuffer/main.tes");
    }

    registerShader(waterShader.build());

    // registerShader(mainShaderOpaque("hand-solid", Usage.HAND)
    //     .define("RENDER_HAND", "1")
    //     .build());
    //
    // registerShader(mainShaderTranslucent("hand-translucent", Usage.TRANSLUCENT_HAND)
    //     .define("RENDER_HAND", "1")
    //     .build());

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

    if (snapshot.Lighting_Mode == LightingModes.RayTraced) {
        const groupCount = Math.ceil(snapshot.Voxel_Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("light-list")
            .location("composite/light-list.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .build());
    }

    if (snapshot.Lighting_Mode == LightingModes.FloodFill) {
        const groupCount = Math.ceil(snapshot.Voxel_Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("floodfill")
            .location("composite/floodfill.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .define("RENDER_COMPUTE", "1")
            .ssbo(0, sceneBuffer)
            .ubo(0, SceneSettingsBuffer)
            .build());
    }

    if (snapshot.Lighting_GI_Enabled) {
        const groupCount = Math.ceil(snapshot.Voxel_Size / 8);

        const shader = new Compute("global-illumination")
            .location("composite/global-illumination.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .define("RENDER_COMPUTE", "1")
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .ssbo(5, blockFaceBuffer)
            .ubo(0, SceneSettingsBuffer);

        if (snapshot.Lighting_Mode == LightingModes.RayTraced) {
            registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

            shader.ssbo(3, lightListBuffer);
        }

        registerShader(Stage.POST_RENDER, shader.build());
    }

    if (snapshot.Shadow_Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("shadow-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/shadow-opaque.fsh")
            .target(0, texShadow)
            .build());

        if (snapshot.Shadow_Filter) {
            registerShader(Stage.POST_RENDER, new Compute("shadow-opaque-filter")
                .location("composite/shadow-opaque-filter.csh")
                .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                .build());

            //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        }
    }

    const texShadow_src = snapshot.Shadow_Filter ? "texShadow_final" : "texShadow";

    if (snapshot.Lighting_Mode == LightingModes.RayTraced || snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        if (snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
            registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));
            //rtOpaqueShader.generateMips(texFinalPrevious);
        }

        const rtOpaqueShader = new Composite("rt-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define("TEX_DEFERRED_COLOR", "texDeferredOpaque_Color")
            .define("TEX_DEFERRED_DATA", "texDeferredOpaque_Data")
            .define("TEX_DEFERRED_NORMAL", "texDeferredOpaque_TexNormal")
            .define("TEX_DEPTH", "solidDepthTex")
            .define("TEX_SHADOW", texShadow_src);

        // if (settings.Internal.LPV) {
        //     rtOpaqueShader
        //         .ssbo(1, shLpvBuffer)
        //         .ssbo(2, shLpvBuffer_alt);
        // }

        registerShader(Stage.POST_RENDER, rtOpaqueShader.build());
    }

    if (snapshot.Effect_SSAO_Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("ssao-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/ssao.fsh")
            .target(0, texSSAO)
            .ubo(0, SceneSettingsBuffer)
            .build());

        // registerShader(Stage.POST_RENDER, new Compute("ssao-filter-opaque")
        //     // .barrier(true)
        //     .location("composite/ssao-filter-opaque.csh")
        //     .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        //     .build());
    }

    if (settings.Internal.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute("accumulation-opaque")
            .location("composite/accumulation.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define("TEX_DEPTH", "solidDepthTex")
            .define("TEX_SSAO", "texSSAO")
            .define("TEX_DEFERRED_DATA", "texDeferredOpaque_Data")
            .define("IMG_ACCUM_DIFFUSE", "imgAccumDiffuse_opaque")
            .define("IMG_ACCUM_SPECULAR", "imgAccumSpecular_opaque")
            .define("IMG_ACCUM_POSITION", "imgAccumPosition_opaque")
            .define("IMG_ACCUM_DIFFUSE_ALT", "imgAccumDiffuse_opaque_alt")
            .define("IMG_ACCUM_SPECULAR_ALT", "imgAccumSpecular_opaque_alt")
            .define("IMG_ACCUM_POSITION_ALT", "imgAccumPosition_opaque_alt")
            .define("IMG_ACCUM_OCCLUSION", "imgAccumOcclusion_opaque")
            .define("IMG_ACCUM_OCCLUSION_ALT", "imgAccumOcclusion_opaque_alt")
            .define("TEX_ACCUM_DIFFUSE", "texAccumDiffuse_opaque")
            .define("TEX_ACCUM_SPECULAR", "texAccumSpecular_opaque")
            .define("TEX_ACCUM_POSITION", "texAccumPosition_opaque")
            .define("TEX_ACCUM_DIFFUSE_ALT", "texAccumDiffuse_opaque_alt")
            .define("TEX_ACCUM_SPECULAR_ALT", "texAccumSpecular_opaque_alt")
            .define("TEX_ACCUM_POSITION_ALT", "texAccumPosition_opaque_alt")
            .define("TEX_ACCUM_OCCLUSION", "texAccumOcclusion_opaque")
            .define("TEX_ACCUM_OCCLUSION_ALT", "texAccumOcclusion_opaque_alt")
            .build());
    }

    registerShader(Stage.POST_RENDER, new Composite("volumetric-far")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/volumetric-far.fsh")
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        // .ssbo(1, shLpvBuffer)
        // .ssbo(2, shLpvBuffer_alt)
        .ubo(0, SceneSettingsBuffer)
        .build());

    registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT | IMAGE_BIT));

    const compositeOpaqueShader = new Composite("composite-opaque")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-opaque.fsh")
        .target(0, texFinalOpaque)
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        .ubo(0, SceneSettingsBuffer)
        .define("TEX_SHADOW", texShadow_src)
        .define("TEX_SSAO", "texSSAO_final");

    // if (snapshot.Lighting_ReflectionMode == ReflectMode_SSR)
    //     compositeOpaqueShader.generateMips(texFinalPrevious);

    if (snapshot.Lighting_GI_Enabled) {
        compositeOpaqueShader
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);
    }

    registerShader(Stage.POST_RENDER, compositeOpaqueShader.build());

    if (snapshot.Lighting_Mode == LightingModes.RayTraced || snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        if (snapshot.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
            registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));
            //rtTranslucentShader.generateMips(texFinalPrevious);
        }

        registerShader(Stage.POST_RENDER, new Composite("rt-translucent")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define("RENDER_TRANSLUCENT", "1")
            .define("TEX_DEFERRED_COLOR", "texDeferredTrans_Color")
            .define("TEX_DEFERRED_DATA", "texDeferredTrans_Data")
            .define("TEX_DEFERRED_NORMAL", "texDeferredTrans_TexNormal")
            .define("TEX_DEPTH", "mainDepthTex")
            .define("TEX_SHADOW", texShadow_src)
            .build());
    }

    if (settings.Internal.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute("accumulation-translucent")
            .location("composite/accumulation.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define("RENDER_TRANSLUCENT", "1")
            .define("TEX_DEPTH", "mainDepthTex")
            .define("TEX_SSAO", "texSSAO")
            .define("TEX_DEFERRED_DATA", "texDeferredTrans_Data")
            .define("IMG_ACCUM_DIFFUSE", "imgAccumDiffuse_translucent")
            .define("IMG_ACCUM_SPECULAR", "imgAccumSpecular_translucent")
            .define("IMG_ACCUM_POSITION", "imgAccumPosition_translucent")
            .define("IMG_ACCUM_DIFFUSE_ALT", "imgAccumDiffuse_translucent_alt")
            .define("IMG_ACCUM_SPECULAR_ALT", "imgAccumSpecular_translucent_alt")
            .define("IMG_ACCUM_POSITION_ALT", "imgAccumPosition_translucent_alt")
            .define("IMG_ACCUM_OCCLUSION", "imgAccumOcclusion_translucent")
            .define("IMG_ACCUM_OCCLUSION_ALT", "imgAccumOcclusion_translucent_alt")
            .define("TEX_ACCUM_DIFFUSE", "texAccumDiffuse_translucent")
            .define("TEX_ACCUM_SPECULAR", "texAccumSpecular_translucent")
            .define("TEX_ACCUM_POSITION", "texAccumPosition_translucent")
            .define("TEX_ACCUM_DIFFUSE_ALT", "texAccumDiffuse_translucent_alt")
            .define("TEX_ACCUM_SPECULAR_ALT", "texAccumSpecular_translucent_alt")
            .define("TEX_ACCUM_POSITION_ALT", "texAccumPosition_translucent_alt")
            .define("TEX_ACCUM_OCCLUSION", "texAccumOcclusion_translucent")
            .define("TEX_ACCUM_OCCLUSION_ALT", "texAccumOcclusion_translucent_alt")
            .build());
    }

    registerShader(Stage.POST_RENDER, new Composite("volumetric-near")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/volumetric-near.fsh")
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        // .ssbo(1, shLpvBuffer)
        // .ssbo(2, shLpvBuffer_alt)
        .ubo(0, SceneSettingsBuffer)
        .build());

    if (snapshot.Lighting_VolumetricResolution > 0) {
        registerShader(Stage.POST_RENDER, new Compute("volumetric-near-filter")
            .location("composite/volumetric-filter.csh")
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define("TEX_DEPTH", "mainDepthTex")
            .build());
    }

    registerShader(Stage.POST_RENDER, new GenerateMips(texFinalOpaque));

    if (snapshot.Shadow_Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("shadow-translucent")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/shadow-translucent.fsh")
            .target(0, texShadow)
            .build());

        // if (snapshot.Shadow_Filter) {
        //     registerShader(Stage.POST_RENDER, new Compute("shadow-translucent-filter")
        //         .location("composite/shadow-opaque-filter.csh")
        //         .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        //         .build());
        //
        //     //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        // }
    }

    registerShader(Stage.POST_RENDER, new Composite("composite-translucent")
        .vertex("shared/bufferless.vsh")
        .fragment("composite/composite-translucent.fsh")
        .target(0, texFinal)
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        .ubo(0, SceneSettingsBuffer)
        .define("TEX_SHADOW", "texShadow")
        .build());

    if (snapshot.Effect_TAA_Enabled) {
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
        .build());

    registerShader(Stage.POST_RENDER, new Compute("histogram")
        .location("post/histogram.csh")
        .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        .ubo(0, SceneSettingsBuffer)
        .build());

    registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));

    registerShader(Stage.POST_RENDER, new Compute("exposure")
        .workGroups(1, 1, 1)
        .location("post/exposure.csh")
        .ssbo(0, sceneBuffer)
        .ubo(0, SceneSettingsBuffer)
        .build());

    if (snapshot.Effect_BloomEnabled)
        setupBloom(texFinal);

    registerShader(Stage.POST_RENDER, new Composite("tonemap")
        .vertex("shared/bufferless.vsh")
        .fragment("post/tonemap.fsh")
        .ssbo(0, sceneBuffer)
        .ubo(0, SceneSettingsBuffer)
        .target(0, texFinal)
        .build());

    if (settings.Internal.DebugEnabled) {
        registerShader(Stage.POST_RENDER, new Composite("debug")
            .vertex("shared/bufferless.vsh")
            .fragment("post/debug.fsh")
            .target(0, texFinal)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define("TEX_COLOR", snapshot.Debug_Translucent
                ? "texDeferredTrans_Color"
                : "texDeferredOpaque_Color")
            .define("TEX_NORMAL", snapshot.Debug_Translucent
                ? "texDeferredTrans_TexNormal"
                : "texDeferredOpaque_TexNormal")
            .define("TEX_DATA", snapshot.Debug_Translucent
                ? "texDeferredTrans_Data"
                : "texDeferredOpaque_Data")
            .define("TEX_SHADOW", snapshot.Debug_Translucent
                ? "texShadow"
                : texShadow_src)
            .define("TEX_SSAO", "texSSAO")
            .define("TEX_ACCUM_OCCLUSION", snapshot.Debug_Translucent
                ? "texAccumOcclusion_translucent"
                : "texAccumOcclusion_opaque")
            .build());
    }

    setCombinationPass(new CombinationPass("post/final.fsh").build());

    for (let blockName in BlockMappings.mappings) {
        const meta = BlockMappings.get(blockName);
        defineGlobally(meta.define, meta.index.toString());
        //print(`Mapped block '${meta.block}' to '${meta.index}:${meta.define}'`)
    }

    onSettingsChanged(null);
    //setupFrame(null);
}

export function onSettingsChanged(state : WorldState) {
    const snapshot = Settings.getRealTimeSnapshot();

    worldSettings.sunPathRotation = snapshot.Sky_SunAngle;

    const d = snapshot.Sky_FogDensity * 0.01;

    new StreamBufferBuilder(SceneSettingsBuffer)
        .appendFloat(snapshot.Sky_CloudCoverage * 0.01)
        .appendFloat(d*d)
        .appendFloat(snapshot.Sky_SeaLevel)
        .appendInt(snapshot.Water_WaveDetail)
        .appendFloat(snapshot.Water_WaveHeight)
        .appendFloat(snapshot.Water_TessellationLevel)
        .appendFloat(snapshot.Material_EmissionBrightness * 0.01)
        .appendInt(snapshot.Lighting_BlockTemp)
        .appendFloat(snapshot.Lighting_PenumbraSize * 0.01)
        .appendFloat(snapshot.Effect_SSAO_Strength * 0.01)
        .appendFloat(snapshot.Effect_Bloom_Strength * 0.01)
        .appendFloat(snapshot.Post_ExposureMin)
        .appendFloat(snapshot.Post_ExposureMax)
        .appendFloat(snapshot.Post_ExposureRange)
        .appendFloat(snapshot.Post_ExposureSpeed)
        .appendFloat(snapshot.Post_ToneMap_Contrast)
        .appendFloat(snapshot.Post_ToneMap_LinearStart)
        .appendFloat(snapshot.Post_ToneMap_LinearLength)
        .appendFloat(snapshot.Post_ToneMap_Black);
}

export function setupFrame(state : WorldState) {
    //const snapshot = Settings.getRealTimeSnapshot();

    // worldSettings.sunPathRotation = snapshot.Sky_SunAngle;

    // if (isKeyDown(Keys.G)) testVal += 0.07;
    // if (isKeyDown(Keys.F)) testVal -= 0.07;
    // TEST_UBO.setFloat(0, testVal);

    SceneSettingsBuffer.uploadData();
}

export function getBlockId(block : BlockState) : number {
    const name = block.getName();
    const meta = BlockMappings.get(name);
    if (meta != undefined) return meta.index;

    return 0;
}

function setupSky(sceneBuffer) {
    const texSkyTransmit = new Texture("texSkyTransmit")
        .format(Format.RGB16F)
        .clear(false)
        .width(256)
        .height(128)
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
        .ubo(0, SceneSettingsBuffer)
        .build())

    registerShader(Stage.PRE_RENDER, new Composite("sky-irradiance")
        .vertex("shared/bufferless.vsh")
        .fragment("setup/sky_irradiance.fsh")
        .target(0, texSkyIrradiance)
        .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
        .ssbo(0, sceneBuffer)
        .ubo(0, SceneSettingsBuffer)
        .build())
}

function setupBloom(texFinal) {
    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
    maxLod = Math.floor(maxLod - 2);
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
            .ubo(0, SceneSettingsBuffer)
            .define("TEX_SCALE", Math.pow(2, i+1).toString())
            .define("BLOOM_INDEX", i.toString())
            .define("MIP_INDEX", i.toString());

        if (i == 0) {
            shader.target(0, texFinal);
            shader.blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO);
        }
        else {
            shader.target(0, texBloom, i-1);
            shader.blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE);
        }

        registerShader(Stage.POST_RENDER, shader.build());
    }
}

function defineGlobally1(name: string) {defineGlobally(name, "1");}

function cubed(x) {return x*x*x;}
