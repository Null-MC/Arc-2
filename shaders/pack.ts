import {BlockMap} from "./scripts/BlockMap";
import {TagBuilder, BufferFlipper, setLightColorEx, StreamBufferBuilder} from "./scripts/helpers";
import {LightingModes, ReflectionModes, ShaderSettings} from "./scripts/settings";


const LIGHT_BIN_SIZE = 8;
const QUAD_BIN_SIZE = 2;

const SceneSettingsBufferSize = 128;
let SceneSettingsBuffer: BuiltStreamingBuffer;
let BlockMappings: BlockMap;


function applySettings(settings : ShaderSettings, internal) {
    worldSettings.disableShade = true;
    worldSettings.ambientOcclusionLevel = 0.0;
    //worldSettings.shadowMapResolution = settings.Shadow_Resolution;
    //worldSettings.cascadeCount = settings.Shadow_CascadeCount;
    worldSettings.pointNearPlane = 0.05;
    worldSettings.pointFarPlane = 16.0;
    worldSettings.pointResolution = 128;
    worldSettings.pointMaxUpdates = settings.Lighting_Shadow_UpdateCount;
    worldSettings.pointRealTime = settings.Lighting_Shadow_RealtimeCount;
    worldSettings.pointUpdateThreshold = settings.Lighting_Shadow_UpdateThreshold * 0.01;
    worldSettings.renderWaterOverlay = false;
    worldSettings.renderStars = false;
    worldSettings.renderMoon = false;
    worldSettings.renderSun = false;
    // worldSettings.vignette = false;
    // worldSettings.clouds = false;

    // TODO: fix hands later, for now just unbreak them
    worldSettings.mergedHandDepth = true;

    if (settings.Shadow_Enabled) {
        enableShadows(settings.Shadow_Resolution, settings.Shadow_CascadeCount);

        if (settings.Shadow_CascadeCount == 1) {
            worldSettings.shadowNearPlane = -200;
            worldSettings.shadowFarPlane = 200;
        }

        if (!settings.Voxel_UseProvided || internal.VoxelizeBlockFaces || internal.VoxelizeTriangles)
            worldSettings.cascadeSafeZones[0] = settings.Voxel_Size / 2;
    }

    defineGlobally1("EFFECT_VL_ENABLED");
    if (internal.Accumulation) defineGlobally1('ACCUM_ENABLED');

    if (settings.Sky_Wind_Enabled) defineGlobally1('SKY_WIND_ENABLED')
    if (settings.Sky_CloudsEnabled) defineGlobally1('SKY_CLOUDS_ENABLED');
    if (settings.Fog_NoiseEnabled) defineGlobally1('SKY_FOG_NOISE');
    if (settings.Fog_CaveEnabled) defineGlobally1('FOG_CAVE_ENABLED');

    if (settings.Water_WaveEnabled) {
        defineGlobally1('WATER_WAVES_ENABLED');

        if (settings.Water_TessellationEnabled)
            defineGlobally1('WATER_TESSELLATION_ENABLED');
    }

    if (settings.Shadow_Enabled) defineGlobally1('SHADOWS_ENABLED');
    if (settings.Shadow_CloudEnabled) defineGlobally1('SHADOWS_CLOUD_ENABLED');
    if (settings.Shadow_SS_Fallback) defineGlobally1('SHADOWS_SS_FALLBACK');
    defineGlobally('SHADOW_RESOLUTION', settings.Shadow_Resolution);
    defineGlobally('SHADOW_CASCADE_COUNT', settings.Shadow_CascadeCount);

    function getChannelFormat(channelFormat: number) {
        return (channelFormat >= 0) ? channelFormat : settings.Material_Format;
    }

    defineGlobally('MATERIAL_FORMAT', settings.Material_Format);

    defineGlobally('MATERIAL_NORMAL_FORMAT', getChannelFormat(settings.Material_NormalFormat));
    if (settings.Material_NormalSmooth) defineGlobally1('MATERIAL_NORMAL_SMOOTH');

    defineGlobally('MATERIAL_POROSITY_FORMAT', getChannelFormat(settings.Material_PorosityFormat));

    if (settings.Material_ParallaxEnabled) {
        defineGlobally1('MATERIAL_PARALLAX_ENABLED');
        defineGlobally('MATERIAL_PARALLAX_TYPE', settings.Material_ParallaxType);
        defineGlobally('MATERIAL_PARALLAX_DEPTH', settings.Material_ParallaxDepth);
        defineGlobally('MATERIAL_PARALLAX_SAMPLES', settings.Material_ParallaxStepCount);
        //if (settings.Material_ParallaxSharp) defineGlobally1("MATERIAL_PARALLAX_SHARP");
        if (settings.Material_ParallaxDepthWrite) defineGlobally1('MATERIAL_PARALLAX_DEPTHWRITE');
    }

    defineGlobally('MATERIAL_SSS_FORMAT', getChannelFormat(settings.Material_SSS_Format));
    defineGlobally('MATERIAL_SSS_DISTANCE', settings.Material_SSS_MaxDist);
    defineGlobally('MATERIAL_SSS_RADIUS', settings.Material_SSS_MaxRadius);

    defineGlobally('MATERIAL_EMISSION_FORMAT', getChannelFormat(settings.Material_Emission_Format));

    if (settings.Material_FancyLava) {
        defineGlobally1('FANCY_LAVA');
        defineGlobally('FANCY_LAVA_RES', settings.Material_FancyLavaResolution);
    }

    defineGlobally('LIGHTING_MODE', settings.Lighting_Mode);
    defineGlobally('LIGHTING_VL_RES', settings.Lighting_VolumetricResolution);

    if (settings.Lighting_Mode == LightingModes.ShadowMaps) {
        defineGlobally('LIGHTING_SHADOW_MAX_COUNT', settings.Lighting_Shadow_BinMaxCount);
        if (settings.Lighting_Shadow_PCSS)
            defineGlobally1('LIGHTING_SHADOW_PCSS');
        if (settings.Lighting_Shadow_EmissionMask)
            defineGlobally1('LIGHTING_SHADOW_EMISSION_MASK');
        if (settings.Lighting_Shadow_BinsEnabled)
            defineGlobally1('LIGHTING_SHADOW_BIN_ENABLED');
    }

    if (settings.Lighting_GI_Enabled) {
        defineGlobally1('LIGHTING_GI_ENABLED');
        defineGlobally('VOXEL_GI_MAXSTEP', settings.Lighting_GI_MaxSteps);
        defineGlobally('WSGI_CASCADE_COUNT', settings.Lighting_GI_CascadeCount);
        defineGlobally('LIGHTING_GI_SIZE', settings.Lighting_GI_BufferSize);
        defineGlobally('VOXEL_GI_MAXFRAMES', settings.Lighting_GI_MaxFrames);

        if (settings.Lighting_GI_SkyLight)
            defineGlobally1('LIGHTING_GI_SKYLIGHT');

        defineGlobally('WSGI_SCALE_BASE', settings.Lighting_GI_BaseScale);

        // const scaleF = Math.max(settings.Lighting_GI_BaseScale + settings.Lighting_GI_CascadeCount - 2, 0);
        // const snapScale = Math.pow(2, scaleF);
        // defineGlobally("WSGI_SNAP_SCALE", snapScale);
    }

    if (settings.Lighting_Volumetric_ShadowsEnabled)
        defineGlobally1('LIGHTING_VL_SHADOWS');

    defineGlobally('LIGHTING_REFLECT_MODE', settings.Lighting_ReflectionMode);
    defineGlobally('LIGHTING_REFLECT_MAXSTEP', settings.Lighting_ReflectionStepCount)
    if (settings.Lighting_ReflectionNoise) defineGlobally1('MATERIAL_ROUGH_REFLECT_NOISE');
    if (settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        if (settings.Lighting_ReflectionQuads) defineGlobally1('LIGHTING_REFLECT_TRIANGLE');
    }

    //if (internal.VoxelizeBlocks) {
        //defineGlobally1('VOXEL_ENABLED');
        defineGlobally('VOXEL_SIZE', settings.Voxel_Size);
        defineGlobally('VOXEL_FRUSTUM_OFFSET', settings.Voxel_Offset);

        defineGlobally('LIGHT_BIN_SIZE', LIGHT_BIN_SIZE);
        defineGlobally('RT_MAX_LIGHT_COUNT', settings.Lighting_TraceLightMax);

        if (settings.Voxel_UseProvided)
            defineGlobally1('VOXEL_PROVIDED');

        if (settings.Lighting_Mode == LightingModes.RayTraced) {
            defineGlobally1('RT_ENABLED');
            defineGlobally('RT_MAX_SAMPLE_COUNT', `${settings.Lighting_TraceSampleCount}u`);
            // defineGlobally("RT_MAX_LIGHT_COUNT", settings.Lighting_TraceLightMax);
            //defineGlobally("LIGHT_BIN_MAX", snapshot.Voxel_MaxLightCount);

            if (settings.Lighting_TraceQuads) defineGlobally1('RT_TRI_ENABLED');
        }

        if (internal.VoxelizeBlockFaces)
            defineGlobally1('VOXEL_BLOCK_FACE');

        if (internal.VoxelizeTriangles) {
            defineGlobally1('VOXEL_TRI_ENABLED');
            defineGlobally('QUAD_BIN_MAX', settings.Voxel_MaxQuadCount);
            defineGlobally('QUAD_BIN_SIZE', QUAD_BIN_SIZE);
        }

        if (settings.Lighting_Mode == LightingModes.FloodFill)
            defineGlobally1('LPV_ENABLED');
    //}

    if (settings.Effect_SSAO_Enabled) defineGlobally1('EFFECT_SSAO_ENABLED');
    defineGlobally('EFFECT_SSAO_SAMPLES', settings.Effect_SSAO_StepCount);

    defineGlobally('EFFECT_DOF_SAMPLES', settings.Effect_DOF_SampleCount);
    defineGlobally('EFFECT_DOF_SPEED', settings.Effect_DOF_Speed);

    if (settings.Post_TAA_Enabled) defineGlobally1('EFFECT_TAA_ENABLED');

    if (settings.Post_PurkinjeEnabled) defineGlobally1('POST_PURKINJE_ENABLED');

    if (settings.Debug_WhiteWorld) defineGlobally1('DEBUG_WHITE_WORLD');
    if (settings.Debug_Exposure) defineGlobally1('DEBUG_EXPOSURE');
    if (settings.Debug_LightCount) defineGlobally1('DEBUG_LIGHT_COUNT')
    if (settings.Debug_RT) defineGlobally1('DEBUG_RT');
    //if (snapshot.Debug_QuadLists) defineGlobally1("DEBUG_QUADS");

    if (internal.DebugEnabled) {
        print('Shader Debug view enabled!')

        defineGlobally("DEBUG_VIEW", settings.Debug_View);
        defineGlobally("DEBUG_MATERIAL", settings.Debug_Material);
        if (settings.Debug_Translucent) defineGlobally1("DEBUG_TRANSLUCENT");
    }
}

// function mapTag(index: number, name: string, namespace: NamespacedId) {
//     addTag(index, namespace);
//     defineGlobally(name, index);
// }

export function setupShader(dimension : NamespacedId) {
    print(`Setting up shader [DIM: ${dimension.getPath()}]`);

    BlockMappings = new BlockMap();
    BlockMappings.map('grass_block', 'BLOCK_GRASS');
    BlockMappings.map('lava', 'BLOCK_LAVA');

    const settings = new ShaderSettings();
    const internal = settings.BuildInternalSettings();
    applySettings(settings, internal);

    const blockTags = new TagBuilder()
        //.map("TAG_FOLIAGE", new NamespacedId("aperture", "foliage"))
        .map("TAG_LEAVES", new NamespacedId("minecraft", "leaves"))
        .map("TAG_STAIRS", new NamespacedId("minecraft", "stairs"))
        .map("TAG_SLABS", new NamespacedId("minecraft", "slabs"))
        .map("TAG_SNOW", new NamespacedId("minecraft", "snow"));

    blockTags.map('TAG_FOLIAGE_GROUND', createTag(new NamespacedId('arc', 'foliage_ground'),
        new NamespacedId('acacia_sapling'),
        new NamespacedId('birch_sapling'),
        new NamespacedId('cherry_sapling'),
        new NamespacedId('jungle_sapling'),
        new NamespacedId('oak_sapling'),
        new NamespacedId('dark_oak_sapling'),
        new NamespacedId('pale_oak_sapling'),
        new NamespacedId('spruce_sapling'),
        new NamespacedId('allium'),
        new NamespacedId('azalea'),
        new NamespacedId('flowering_azalea'),
        new NamespacedId('azure_bluet'),
        new NamespacedId('beetroots'),
        new NamespacedId('blue_orchid'),
        new NamespacedId('bush'),
        new NamespacedId('cactus_flower'),
        new NamespacedId('carrots'),
        new NamespacedId('cornflower'),
        new NamespacedId('crimson_roots'),
        new NamespacedId('dead_bush'),
        new NamespacedId('dandelion'),
        new NamespacedId('open_eyeblossom'),
        new NamespacedId('closed_eyeblossom'),
        new NamespacedId('short_dry_grass'),
        new NamespacedId('tall_dry_grass'),
        new NamespacedId('fern'),
        new NamespacedId('firefly_bush'),
        new NamespacedId('grass'),
        new NamespacedId('short_grass'),
        new NamespacedId('lily_of_the_valley'),
        new NamespacedId('mangrove_propagule'),
        new NamespacedId('nether_sprouts'),
        new NamespacedId('orange_tulip'),
        new NamespacedId('oxeye_daisy'),
        new NamespacedId('pink_petals'),
        new NamespacedId('pink_tulip'),
        new NamespacedId('poppy'),
        new NamespacedId('potatoes'),
        new NamespacedId('red_tulip'),
        new NamespacedId('sweet_berry_bush'),
        new NamespacedId('torchflower'),
        new NamespacedId('torchflower_crop'),
        new NamespacedId('warped_roots'),
        new NamespacedId('wheat'),
        new NamespacedId('white_tulip'),
        new NamespacedId('wildflowers'),
        new NamespacedId('wither_rose')));

    // blockTags.map('TAG_WAVING_TOP', createTag(new NamespacedId('arc', 'waving_top'),
    //     new NamespacedId('lantern')));

    blockTags.map('TAG_WAVING_FULL', createTag(new NamespacedId('arc', 'waving_full'),
        new NamespacedId('birch_leaves'),
        new NamespacedId('cherry_leaves'),
        new NamespacedId('jungle_leaves'),
        new NamespacedId('mangrove_leaves'),
        new NamespacedId('oak_leaves'),
        new NamespacedId('dark_oak_leaves'),
        new NamespacedId('pale_oak_leaves'),
        new NamespacedId('spruce_leaves')));

    blockTags.map("TAG_CARPET", createTag(new NamespacedId("arc", "carpets"),
        //new NamespacedId("minecraft", "wool_carpets"),
        new NamespacedId("white_carpet"),
        new NamespacedId("light_gray_carpet"),
        new NamespacedId("gray_carpet"),
        new NamespacedId("black_carpet"),
        new NamespacedId("brown_carpet"),
        new NamespacedId("red_carpet"),
        new NamespacedId("orange_carpet"),
        new NamespacedId("yellow_carpet"),
        new NamespacedId("lime_carpet"),
        new NamespacedId("green_carpet"),
        new NamespacedId("cyan_carpet"),
        new NamespacedId("light_blue_carpet"),
        new NamespacedId("blue_carpet"),
        new NamespacedId("purple_carpet"),
        new NamespacedId("magenta_carpet"),
        new NamespacedId("pink_carpet"),
        new NamespacedId("pale_moss_carpet"),
        new NamespacedId("moss_carpet")));

    blockTags.map("TAG_TINTS_LIGHT", createTag(new NamespacedId("arc", "tints_light"),
        new NamespacedId("minecraft", "glass_blocks"),
        new NamespacedId("tinted_glass"),
        new NamespacedId("white_stained_glass"),
        new NamespacedId("white_stained_glass_pane"),
        new NamespacedId("light_gray_stained_glass"),
        new NamespacedId("light_gray_stained_glass_pane"),
        new NamespacedId("gray_stained_glass"),
        new NamespacedId("gray_stained_glass_pane"),
        new NamespacedId("black_stained_glass"),
        new NamespacedId("black_stained_glass_pane"),
        new NamespacedId("brown_stained_glass"),
        new NamespacedId("brown_stained_glass_pane"),
        new NamespacedId("red_stained_glass"),
        new NamespacedId("red_stained_glass"),
        new NamespacedId("orange_stained_glass"),
        new NamespacedId("orange_stained_glass_pane"),
        new NamespacedId("yellow_stained_glass"),
        new NamespacedId("yellow_stained_glass_pane"),
        new NamespacedId("lime_stained_glass"),
        new NamespacedId("lime_stained_glass_pane"),
        new NamespacedId("green_stained_glass"),
        new NamespacedId("green_stained_glass_pane"),
        new NamespacedId("cyan_stained_glass"),
        new NamespacedId("cyan_stained_glass_pane"),
        new NamespacedId("light_blue_stained_glass"),
        new NamespacedId("light_blue_stained_glass_pane"),
        new NamespacedId("blue_stained_glass"),
        new NamespacedId("blue_stained_glass_pane"),
        new NamespacedId("purple_stained_glass"),
        new NamespacedId("purple_stained_glass_pane"),
        new NamespacedId("magenta_stained_glass"),
        new NamespacedId("magenta_stained_glass_pane"),
        new NamespacedId("pink_stained_glass"),
        new NamespacedId("pink_stained_glass_pane")));

    setLightColorEx('#362b21', 'brown_mushroom');
    setLightColorEx('#f39849', 'campfire');
    setLightColorEx('#935b2c', 'cave_vines', "cave_vines_plant");
    setLightColorEx('#d39f6d', 'copper_bulb', 'waxed_copper_bulb');
    setLightColorEx('#d39255', 'exposed_copper_bulb', 'waxed_exposed_copper_bulb');
    setLightColorEx('#cf833a', 'weathered_copper_bulb', 'waxed_weathered_copper_bulb');
    setLightColorEx('#87480b', 'oxidized_copper_bulb', 'waxed_oxidized_copper_bulb');
    setLightColorEx('#7f17a8', 'crying_obsidian', 'respawn_anchor');
    setLightColorEx('#371559', "enchanting_table");
    setLightColorEx('#bea935', "firefly_bush");
    setLightColorEx('#5f9889', "glow_lichen");
    setLightColorEx('#d3b178', "glowstone");
    setLightColorEx('#c2985a', 'jack_o_lantern');
    setLightColorEx('#f39e49', 'lantern');
    setLightColorEx('#b8491c', "lava");
    setLightColorEx('#650a5e', "nether_portal");
    setLightColorEx('#dfac47', "ochre_froglight");
    setLightColorEx('#e075e8', 'pearlescent_froglight');
    setLightColorEx('#f9321c', 'redstone_torch', 'redstone_wall_torch');
    setLightColorEx('#e0ba42', 'redstone_lamp');
    setLightColorEx('#f9321c', 'redstone_ore', 'deepslate_redstone_ore');
    setLightColorEx('#8bdff8', 'sea_lantern');
    setLightColorEx('#28aaeb', 'soul_torch', 'soul_wall_torch', 'soul_campfire');
    setLightColorEx('#f3b549', 'torch', 'wall_torch');
    setLightColorEx('#63e53c', 'verdant_froglight');

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

    if (settings.Lighting_ColorCandles) {
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

    for (let blockName in BlockMappings.mappings) {
        const meta = BlockMappings.get(blockName);
        defineGlobally(meta.define, meta.index.toString());
        //print(`Mapped block '${meta.block}' to '${meta.index}:${meta.define}'`)
    }

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
        .width(settings.Shadow_Resolution)
        .height(settings.Shadow_Resolution)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .build();

    const texShadowBlocker = new ArrayTexture("texShadowBlocker")
        .imageName('imgShadowBlocker')
        .format(Format.R16F)
        .width(settings.Shadow_Resolution/2)
        .height(settings.Shadow_Resolution/2)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .build();

    // const texShadowNormal = new ArrayTexture("texShadowNormal")
    //     .format(Format.RGB8)
    //     //.clearColor(0.0, 0.0, 0.0, 0.0)
    //     .clear(false)
    //     .build();

    const texFinalA = new Texture("texFinalA")
        //.imageName("imgFinalA")
        .format(Format.RGB16F)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .mipmap(true)
        .clear(false)
        .build();

    const texFinalB = new Texture("texFinalB")
        //.imageName("imgFinalB")
        .format(Format.RGB16F)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .mipmap(true)
        .clear(false)
        .build();

    const finalFlipper = new BufferFlipper(
        'texFinalA', texFinalA,
        'texFinalB', texFinalB);

    const texFinalPrevious = new Texture("texFinalPrevious")
        .format(Format.RGB16F)
        .mipmap(true)
        .width(screenWidth)
        .height(screenHeight)
        .clear(false)
        .build();

    // const texClouds = new Texture("texClouds")
    //     .format(Format.RGBA16F)
    //     .clearColor(0.0, 0.0, 0.0, 0.0)
    //     .build();

    // texParticles
    const texParticleOpaque = new Texture("texParticleOpaque")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texParticleTranslucent = new Texture("texParticleTranslucent")
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_Color = new Texture("texDeferredOpaque_Color")
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_TexNormal = new Texture("texDeferredOpaque_TexNormal")
        .format(Format.RGB16)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_Data = new Texture("texDeferredOpaque_Data")
        .format(Format.RGBA32UI)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredTrans_Color = new Texture("texDeferredTrans_Color")
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredTrans_TexNormal = new Texture("texDeferredTrans_TexNormal")
        .format(Format.RGB16)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredTrans_Data = new Texture("texDeferredTrans_Data")
        .format(Format.RGBA32UI)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredTrans_Depth = new Texture("texDeferredTrans_Depth")
        .format(Format.R32F)
        .clearColor(1.0, 1.0, 1.0, 1.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    let texShadow: BuiltTexture | null = null;
    let texShadow_final: BuiltTexture | null = null;
    if (settings.Shadow_Enabled) {
        texShadow = new Texture("texShadow")
            .format(Format.RGBA16F)
            .clear(false)
            .width(screenWidth)
            .height(screenHeight)
            .build();

        texShadow_final = new Texture("texShadow_final")
            .imageName("imgShadow_final")
            .format(Format.RGBA16F)
            .clear(false)
            .width(screenWidth)
            .height(screenHeight)
            .build();
    }

    if (!settings.Voxel_UseProvided) {
        new Texture("texVoxelBlock")
            .imageName("imgVoxelBlock")
            .format(Format.R32UI)
            .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
            .build();
    }

    let texDiffuseRT: BuiltTexture | null = null;
    let texSpecularRT: BuiltTexture | null = null;
    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        texDiffuseRT = new Texture("texDiffuseRT")
            // .imageName("imgDiffuseRT")
            .format(Format.RGB16F)
            // .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();

        texSpecularRT = new Texture("texSpecularRT")
            // .imageName("imgSpecularRT")
            .format(Format.RGB16F)
            // .clearColor(0.0, 0.0, 0.0, 0.0)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();
    }

    let texSSAO: BuiltTexture | null = null;
    let texSSAO_final: BuiltTexture | null = null;
    if (settings.Effect_SSAO_Enabled) {
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

    if (internal.Accumulation) {
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

        if (settings.Effect_SSAO_Enabled) {
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

    const vlScale = Math.pow(2, settings.Lighting_VolumetricResolution);
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

    if (settings.Lighting_VolumetricResolution > 0) {
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
    if (settings.Lighting_GI_Enabled) {
        // f16vec4[3] * VoxelBufferSize^3
        const bufferSize = 48 * cubed(settings.Lighting_GI_BufferSize) * settings.Lighting_GI_CascadeCount;

        shLpvBuffer = new GPUBuffer(bufferSize)
            .clear(false)
            .build();

        shLpvBuffer_alt = new GPUBuffer(bufferSize)
            .clear(false)
            .build();
    }

    if (settings.Lighting_Mode == LightingModes.FloodFill) {
        const texFloodFill = new Texture("texFloodFill")
            .imageName("imgFloodFill")
            .format(Format.RGBA16F)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
            .clear(false)
            .build();

        const texFloodFill_alt = new Texture("texFloodFill_alt")
            .imageName("imgFloodFill_alt")
            .format(Format.RGBA16F)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
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

    if (settings.Debug_Exposure) {
        const texHistogram_debug = new Texture("texHistogram_debug")
            .imageName("imgHistogram_debug")
            .format(Format.R32UI)
            .width(256)
            .height(1)
            .clear(false)
            .build();
    }

    let texTaaPrev: BuiltTexture|null = null;
    if (settings.Post_TAA_Enabled) {
        texTaaPrev = new Texture("texTaaPrev")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    const sceneBuffer = new GPUBuffer(1024)
        .clear(false)
        .build();

    let lightListBuffer: BuiltBuffer | null = null;
    if (internal.LightListsEnabled) {
        const counterSize = settings.Lighting_Mode == LightingModes.ShadowMaps ? 2 : 1;
        const lightSize = settings.Lighting_Mode == LightingModes.ShadowMaps ? 2 : 1;

        const maxCount = settings.Lighting_Mode == LightingModes.ShadowMaps
            ? settings.Lighting_Shadow_BinMaxCount
            : settings.Lighting_TraceLightMax;

        const lightBinSize = 4 * (counterSize + maxCount*lightSize);
        const lightListBinCount = Math.ceil(settings.Voxel_Size / LIGHT_BIN_SIZE);
        const lightListBufferSize = lightBinSize * cubed(lightListBinCount) + 4;
        print(`Light-List Buffer Size: ${lightListBufferSize.toLocaleString()}`);

        lightListBuffer = new GPUBuffer(lightListBufferSize)
            .clear(false)
            .build();
    }

    let blockFaceBuffer: BuiltBuffer | null = null;
    if (internal.VoxelizeBlockFaces) {
        const bufferSize = 6 * 8 * cubed(settings.Voxel_Size);

        blockFaceBuffer = new GPUBuffer(bufferSize)
            .clear(false) // TODO: clear with compute
            .build();
    }

    let quadListBuffer: BuiltBuffer | null = null;
    if (internal.VoxelizeTriangles) {
        const quadBinSize = 4 + 40*settings.Voxel_MaxQuadCount;
        const quadListBinCount = Math.ceil(settings.Voxel_Size / QUAD_BIN_SIZE);
        const quadListBufferSize = quadBinSize * cubed(quadListBinCount) + 4;
        print(`Quad-List Buffer Size: ${quadListBufferSize.toLocaleString()}`);

        quadListBuffer = new GPUBuffer(quadListBufferSize)
            .clear(true) // TODO: clear with compute
            .build();
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

    if (settings.Lighting_GI_Enabled) {
        registerShader(Stage.SCREEN_SETUP, new Compute("wsgi-clear")
            .location("setup/wsgi-clear.csh")
            .workGroups(8, 8, 8)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .build());
    }

    if (internal.LightListsEnabled) {
        const binCount = Math.ceil(settings.Voxel_Size / LIGHT_BIN_SIZE);
        const groupCount = Math.ceil(binCount / 8);

        print(`light list clear bounds: [${groupCount}]^3`);

        registerShader(Stage.PRE_RENDER, new Compute("light-list-clear")
            .location("setup/light-list-clear.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .ssbo(3, lightListBuffer)
            .build());
    }

    registerShader(Stage.PRE_RENDER, new Compute("scene-prepare")
        .workGroups(1, 1, 1)
        .location("setup/scene-prepare.csh")
        .ssbo(0, sceneBuffer)
        .ssbo(3, lightListBuffer)
        .ssbo(4, quadListBuffer)
        .ubo(0, SceneSettingsBuffer)
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
            .vertex("gbuffer/shadow-celestial.vsh")
            .fragment("gbuffer/shadow-celestial.fsh")
            .ssbo(0, sceneBuffer)
            // .ssbo(4, quadListBuffer)
            .target(0, texShadowColor)
            //.blendOff(0)
            //.target(1, texShadowNormal)
            //.blendOff(1);
            .define("RENDER_SHADOW", "1");
    }

    function shadowTerrainShader(name: string, usage: ProgramUsage) : ObjectShader {
        return shadowShader(name, usage)
            .geometry("gbuffer/shadow-celestial.gsh")
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .define("RENDER_TERRAIN", "1");
    }

    function shadowEntityShader(name: string, usage: ProgramUsage) : ObjectShader {
        const shader = shadowShader(name, usage)
            .define("RENDER_ENTITY", "1");

        if (internal.VoxelizeTriangles) shader
            .geometry("gbuffer/shadow-celestial.gsh")
            .ssbo(4, quadListBuffer);

        return shader;
    }

    function shadowBlockerShader(layer: number) {
        const blockerGroupSize = settings.Shadow_Resolution/32;

        return new Compute(`shadow-blocker-${layer}`)
            .location("composite/shadow-blocker.csh")
            .workGroups(blockerGroupSize, blockerGroupSize, 1)
            .define('SHADOW_LAYER', layer.toString());
    }

    if (settings.Shadow_Enabled) {
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

        for (let l = 0; l < settings.Shadow_CascadeCount; l++)
            registerShader(Stage.POST_SHADOW, shadowBlockerShader(l).build());
    }

    if (settings.Lighting_Mode == LightingModes.ShadowMaps) {
        registerShader(new ObjectShader('block-shadow', Usage.POINT)
            .vertex("gbuffer/shadow-point.vsh")
            .fragment("gbuffer/shadow-point.fsh")
            .build());
    }

    function DiscardObjectShader(name: string, usage: ProgramUsage) {
        return new ObjectShader(name, usage)
            .vertex("shared/discard.vsh")
            .fragment("shared/noop.fsh")
            .define("RENDER_GBUFFER", "1");
    }

    registerShader(DiscardObjectShader("skybox", Usage.SKYBOX)
        .target(0, texFinalA)
        .build());

    registerShader(DiscardObjectShader("skybox", Usage.SKY_TEXTURES)
        .target(0, texFinalA)
        .build());

    registerShader(DiscardObjectShader("clouds", Usage.CLOUDS)
        .target(0, texFinalA)
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
            .target(3, texDeferredTrans_Depth)
            .blendOff(3)
            // .blendFunc(3, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
            .define("RENDER_TRANSLUCENT", "1");
    }

    registerShader(mainShaderOpaque("basic", Usage.BASIC).build());

    registerShader(mainShaderOpaque("emissive", Usage.EMISSIVE)
        .define("RENDER_EMISSIVE", "1")
        .build());

    registerShader(mainShaderOpaque("terrain-solid", Usage.TERRAIN_SOLID)
        .define("RENDER_TERRAIN", "1")
        .build());

    registerShader(mainShaderOpaque("terrain-cutout", Usage.TERRAIN_CUTOUT)
        .define("RENDER_TERRAIN", "1")
        .build());

    const waterShader = mainShaderTranslucent("terrain-translucent", Usage.TERRAIN_TRANSLUCENT)
        .ubo(0, SceneSettingsBuffer)
        .define("RENDER_TERRAIN", "1");

    if (settings.Water_WaveEnabled && settings.Water_TessellationEnabled) {
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

    registerShader(mainShaderTranslucent('entity-translucent', Usage.ENTITY_TRANSLUCENT)
        .define('RENDER_ENTITY', '1')
        .build());

    function particleShader(name: string, usage: ProgramUsage) {
        const shader = new ObjectShader(name, usage)
            .vertex('gbuffer/particles.vsh')
            .fragment('gbuffer/particles.fsh')
            .ssbo(0, sceneBuffer)
            .ubo(0, SceneSettingsBuffer);

        if (settings.Lighting_GI_Enabled) {
            shader
                .ssbo(1, shLpvBuffer)
                .ssbo(2, shLpvBuffer_alt);
        }

        return shader;
    }

    registerShader(particleShader('particle-opaque', Usage.PARTICLES)
        .target(0, texParticleOpaque)
        .blendOff(0)
        .build());

    registerShader(particleShader('particle-translucent', Usage.PARTICLES_TRANSLUCENT)
        .target(0, texParticleTranslucent)
        .blendOff(0)
        .define('RENDER_TRANSLUCENT', '1')
        .build());

    registerShader(new ObjectShader("weather", Usage.WEATHER)
        .vertex("gbuffer/weather.vsh")
        .fragment("gbuffer/weather.fsh")
        .target(0, texParticleTranslucent)
        .ssbo(0, sceneBuffer)
        .build());

    if (settings.Lighting_Mode == LightingModes.ShadowMaps && settings.Lighting_Shadow_BinsEnabled) {
        const MaxLightCount = 64;
        const pointGroupCount = Math.ceil(MaxLightCount / (8*8*8));
        const voxelGroupCount = Math.ceil(settings.Voxel_Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("light-list-point")
            .location("composite/light-list-shadow.csh")
            .workGroups(pointGroupCount, pointGroupCount, pointGroupCount)
            .ssbo(3, lightListBuffer)
            .build());

        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        registerShader(Stage.POST_RENDER, new Compute("light-list-neighbors")
            .location("composite/light-list-shadow-neighbors.csh")
            .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
            .ssbo(3, lightListBuffer)
            .build());

        if (settings.Lighting_Shadow_VoxelFill) {
            registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

            registerShader(Stage.POST_RENDER, new Compute("light-list-voxel")
                .location("composite/light-list-voxel.csh")
                .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
                .ssbo(3, lightListBuffer)
                .build());

            registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

            registerShader(Stage.POST_RENDER, new Compute("light-list-voxel-neighbors")
                .location("composite/light-list-voxel-neighbors.csh")
                .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
                .ssbo(3, lightListBuffer)
                .build());
        }
    }
    else if (settings.Lighting_Mode == LightingModes.RayTraced) {
        const voxelGroupCount = Math.ceil(settings.Voxel_Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("light-list")
            .location("composite/light-list.csh")
            .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .build());
    }

    if (settings.Lighting_Mode == LightingModes.FloodFill) {
        const groupCount = Math.ceil(settings.Voxel_Size / 8);

        registerShader(Stage.POST_RENDER, new Compute("floodfill")
            .location("composite/floodfill.csh")
            .workGroups(groupCount, groupCount, groupCount)
            .define("RENDER_COMPUTE", "1")
            .ssbo(0, sceneBuffer)
            .ubo(0, SceneSettingsBuffer)
            .build());
    }

    if (settings.Lighting_GI_Enabled) {
        const groupCount = Math.ceil(settings.Lighting_GI_BufferSize / 8);

        for (let i = settings.Lighting_GI_CascadeCount-1; i >= 0; i--) {
            let shader = new Compute(`global-illumination-${i+1}`)
                .location("composite/global-illumination.csh")
                .workGroups(groupCount, groupCount, groupCount)
                .define("RENDER_COMPUTE", "1")
                .define("WSGI_VOXEL_SCALE", (i + settings.Lighting_GI_BaseScale).toString())
                .define("WSGI_CASCADE", i.toString())
                .ssbo(0, sceneBuffer)
                .ssbo(1, shLpvBuffer)
                .ssbo(2, shLpvBuffer_alt)
                .ssbo(5, blockFaceBuffer)
                .ubo(0, SceneSettingsBuffer);

            if (internal.LightListsEnabled) {
                registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

                shader.ssbo(3, lightListBuffer);
            }

            registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

            registerShader(Stage.POST_RENDER, shader.build());
        }
    }

    if (settings.Shadow_Enabled) {
        registerShader(Stage.POST_RENDER, new Composite("shadow-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/shadow-opaque.fsh")
            .target(0, texShadow)
            .build());

        if (settings.Shadow_Filter) {
            registerShader(Stage.POST_RENDER, new Compute("shadow-opaque-filter")
                .location("composite/shadow-opaque-filter.csh")
                .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                .build());

            //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        }
    }

    const texShadow_src = settings.Shadow_Filter ? "texShadow_final" : "texShadow";

    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        const rtOpaqueShader = new Composite("rt-opaque")
            .vertex("shared/bufferless.vsh")
            .fragment("composite/rt.fsh")
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define("TEX_DEFERRED_COLOR", "texDeferredOpaque_Color")
            .define("TEX_DEFERRED_DATA", "texDeferredOpaque_Data")
            .define("TEX_DEFERRED_NORMAL", "texDeferredOpaque_TexNormal")
            .define("TEX_DEPTH", "solidDepthTex")
            .define("TEX_SHADOW", texShadow_src);

        if (settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace && settings.Lighting_GI_Enabled) {
            rtOpaqueShader
                .ssbo(1, shLpvBuffer)
                .ssbo(2, shLpvBuffer_alt);
        }

        if (settings.Lighting_Mode == LightingModes.RayTraced) {
            rtOpaqueShader
                .ssbo(3, lightListBuffer);
        }

        registerShader(Stage.POST_RENDER, rtOpaqueShader.build());
    }

    if (settings.Effect_SSAO_Enabled) {
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

    if (internal.Accumulation) {
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
        .vertex('shared/bufferless.vsh')
        .fragment('composite/composite-opaque.fsh')
        .target(0, finalFlipper.getWriteTexture())
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        .ssbo(5, blockFaceBuffer)
        .ubo(0, SceneSettingsBuffer)
        .define('TEX_SHADOW', texShadow_src)
        .define('TEX_SSAO', 'texSSAO_final');

    if (settings.Lighting_Mode == LightingModes.ShadowMaps)
        compositeOpaqueShader.ssbo(3, lightListBuffer);

    if (settings.Lighting_GI_Enabled) {
        compositeOpaqueShader
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt);
    }

    registerShader(Stage.POST_RENDER, compositeOpaqueShader.build());

    finalFlipper.flip();

    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));

        registerShader(Stage.POST_RENDER, new Composite('rt-translucent')
            .vertex('shared/bufferless.vsh')
            .fragment('composite/rt.fsh')
            .target(0, texDiffuseRT)
            .target(1, texSpecularRT)
            .ssbo(0, sceneBuffer)
            .ssbo(1, shLpvBuffer)
            .ssbo(2, shLpvBuffer_alt)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ssbo(5, blockFaceBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define('RENDER_TRANSLUCENT', '1')
            .define('TEX_DEFERRED_COLOR', 'texDeferredTrans_Color')
            .define('TEX_DEFERRED_DATA', 'texDeferredTrans_Data')
            .define('TEX_DEFERRED_NORMAL', 'texDeferredTrans_TexNormal')
            .define('TEX_DEPTH', 'mainDepthTex')
            .define('TEX_SHADOW', texShadow_src)
            .build());
    }

    if (internal.Accumulation) {
        registerShader(Stage.POST_RENDER, new Compute('accumulation-translucent')
            .location('composite/accumulation.csh')
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define('RENDER_TRANSLUCENT', '1')
            .define('TEX_DEPTH', 'mainDepthTex')
            .define('TEX_SSAO', 'texSSAO')
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

    const vlNearShader = new Composite('volumetric-near')
        .vertex('shared/bufferless.vsh')
        .fragment('composite/volumetric-near.fsh')
        .target(0, texScatterVL)
        .target(1, texTransmitVL)
        .ssbo(0, sceneBuffer)
        // .ssbo(1, shLpvBuffer)
        // .ssbo(2, shLpvBuffer_alt)
        .ubo(0, SceneSettingsBuffer);

    if (internal.LightListsEnabled)
        vlNearShader.ssbo(3, lightListBuffer);

    registerShader(Stage.POST_RENDER, vlNearShader.build());

    if (settings.Lighting_VolumetricResolution > 0) {
        registerShader(Stage.POST_RENDER, new Compute('volumetric-near-filter')
            .location('composite/volumetric-filter.csh')
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define('TEX_DEPTH', 'mainDepthTex')
            .build());
    }

    registerShader(Stage.POST_RENDER, new GenerateMips(finalFlipper.getReadTexture()));

    if (settings.Shadow_Enabled) {
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

    const compositeTranslucentShader = new Composite('composite-translucent')
        .vertex('shared/bufferless.vsh')
        .fragment('composite/composite-translucent.fsh')
        .target(0, finalFlipper.getWriteTexture())
        .ssbo(0, sceneBuffer)
        .ssbo(4, quadListBuffer)
        .ssbo(5, blockFaceBuffer)
        .ubo(0, SceneSettingsBuffer)
        .define('TEX_SRC', finalFlipper.getReadName())
        .define('TEX_SHADOW', 'texShadow');

    if (settings.Lighting_Mode == LightingModes.ShadowMaps)
        compositeTranslucentShader.ssbo(3, lightListBuffer);

    registerShader(Stage.POST_RENDER, compositeTranslucentShader.build());

    finalFlipper.flip();

    // if (settings.Post_TAA_Enabled) {
    //     registerShader(Stage.POST_RENDER, new Composite('TAA')
    //         .vertex('shared/bufferless.vsh')
    //         .fragment('post/taa.fsh')
    //         .target(0, finalFlipper.getWriteTexture())
    //         .target(1, texAccumTAA)
    //         .define('TEX_SRC', finalFlipper.getReadName())
    //         .build());
    //
    //     finalFlipper.flip();
    // }

    registerShader(Stage.POST_RENDER, new TextureCopy(finalFlipper.getReadTexture(), texFinalPrevious)
        .size(screenWidth, screenHeight)
        .build());

    registerShader(Stage.POST_RENDER, new GenerateMips(texFinalPrevious));

    registerShader(Stage.POST_RENDER, new Composite('blur-near')
        .vertex('shared/bufferless.vsh')
        .fragment('post/blur-near.fsh')
        .target(0, finalFlipper.getWriteTexture())
        .define('TEX_SRC', finalFlipper.getReadName())
        .build());

    finalFlipper.flip();

    if (settings.Effect_DOF_Enabled) {
        registerShader(Stage.POST_RENDER, new GenerateMips(finalFlipper.getReadTexture()));

        registerShader(Stage.POST_RENDER, new Composite('depth-of-field')
            .vertex('shared/bufferless.vsh')
            .fragment('composite/depth-of-field.fsh')
            .target(0, finalFlipper.getWriteTexture())
            .define('TEX_SRC', finalFlipper.getReadName())
            .ubo(0, SceneSettingsBuffer)
            .ssbo(0, sceneBuffer)
            .build());

        finalFlipper.flip();
    }

    registerShader(Stage.POST_RENDER, new Compute('histogram')
        .location('post/histogram.csh')
        .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        .ubo(0, SceneSettingsBuffer)
        .define('TEX_SRC', finalFlipper.getReadName())
        .build());

    registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));

    registerShader(Stage.POST_RENDER, new Compute('exposure')
        .workGroups(1, 1, 1)
        .location('post/exposure.csh')
        .ssbo(0, sceneBuffer)
        .ubo(0, SceneSettingsBuffer)
        .build());

    if (settings.Effect_Bloom_Enabled) {
        setupBloom(finalFlipper.getReadName(), finalFlipper.getWriteTexture());

        finalFlipper.flip();
    }

    registerShader(Stage.POST_RENDER, new Composite('tone-map')
        .vertex('shared/bufferless.vsh')
        .fragment('post/tonemap.fsh')
        .ssbo(0, sceneBuffer)
        .ubo(0, SceneSettingsBuffer)
        .target(0, finalFlipper.getWriteTexture())
        .define('TEX_SRC', finalFlipper.getReadName())
        .build());

    finalFlipper.flip();

    if (settings.Post_TAA_Enabled) {
        registerShader(Stage.POST_RENDER, new Composite('TAA')
            .vertex('shared/bufferless.vsh')
            .fragment('post/taa.fsh')
            .target(0, texTaaPrev)
            .target(1, finalFlipper.getWriteTexture())
            .define('TEX_SRC', finalFlipper.getReadName())
            .build());

        finalFlipper.flip();
    }

    if (internal.DebugEnabled) {
        registerShader(Stage.POST_RENDER, new Composite('debug')
            .vertex('shared/bufferless.vsh')
            .fragment('post/debug.fsh')
            .target(0, finalFlipper.getWriteTexture())
            .ssbo(0, sceneBuffer)
            .ssbo(3, lightListBuffer)
            .ssbo(4, quadListBuffer)
            .ubo(0, SceneSettingsBuffer)
            .define('TEX_SRC', finalFlipper.getReadName())
            .define("TEX_COLOR", settings.Debug_Translucent
                ? "texDeferredTrans_Color"
                : "texDeferredOpaque_Color")
            .define("TEX_NORMAL", settings.Debug_Translucent
                ? "texDeferredTrans_TexNormal"
                : "texDeferredOpaque_TexNormal")
            .define("TEX_DATA", settings.Debug_Translucent
                ? "texDeferredTrans_Data"
                : "texDeferredOpaque_Data")
            .define("TEX_SHADOW", settings.Debug_Translucent
                ? "texShadow"
                : texShadow_src)
            .define("TEX_SSAO", "texSSAO")
            .define("TEX_ACCUM_OCCLUSION", settings.Debug_Translucent
                ? "texAccumOcclusion_translucent"
                : "texAccumOcclusion_opaque")
            .build());

        finalFlipper.flip();
    }

    // TODO: temp workaround
    //defineGlobally('FINAL_TEX_SRC', finalFlipper.getReadName());

    setCombinationPass(new CombinationPass("post/final.fsh")
        .define('TEX_SRC', finalFlipper.getReadName())
        .build());

    onSettingsChanged(null);
    //setupFrame(null);
}

export function onSettingsChanged(state : WorldState) {
    const settings = new ShaderSettings();

    worldSettings.sunPathRotation = settings.Sky_SunAngle;
    worldSettings.pointRealTime = settings.Lighting_Shadow_RealtimeCount;
    worldSettings.pointUpdateThreshold = settings.Lighting_Shadow_UpdateThreshold * 0.01;

    const d = settings.Fog_Density * 0.01;

    new StreamBufferBuilder(SceneSettingsBuffer)
        .appendInt(settings.Sky_SunTemp)
        .appendFloat(settings.Sky_SunAngle)
        .appendFloat(settings.Sky_CloudCoverage * 0.01)
        .appendFloat(d*d)
        .appendFloat(settings.Sky_SeaLevel)
        .appendInt(settings.Water_WaveDetail)
        .appendFloat(settings.Water_WaveHeight)
        .appendFloat(settings.Water_TessellationLevel)
        .appendFloat(settings.Material_Emission_Brightness * 0.01)
        .appendInt(settings.Lighting_BlockTemp)
        .appendFloat(settings.Lighting_PenumbraSize * 0.01)
        .appendFloat(settings.Effect_SSAO_Strength * 0.01)
        .appendFloat(settings.Effect_Bloom_Strength * 0.01)
        .appendFloat(settings.Effect_DOF_Radius)
        .appendFloat(settings.Post_ExposureMin)
        .appendFloat(settings.Post_ExposureMax)
        .appendFloat(settings.Post_ExposureSpeed)
        .appendFloat(settings.Post_ExposureOffset)
        .appendFloat(settings.Post_ToneMap_Contrast)
        .appendFloat(settings.Post_ToneMap_LinearStart)
        .appendFloat(settings.Post_ToneMap_LinearLength)
        .appendFloat(settings.Post_ToneMap_Black);
}

export function setupFrame(state : WorldState) {
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

function setupBloom(src: string, target: BuiltTexture) {
    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
    maxLod = Math.floor(maxLod - 2);
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    const texBloom = new Texture('texBloom')
        .format(Format.RGB16F)
        .width(screenWidth_half)
        .height(screenHeight_half)
        .mipmap(true)
        .clear(false)
        .build();

    for (let i = 0; i < maxLod; i++) {
        registerShader(Stage.POST_RENDER, new Composite(`bloom-down-${i}`)
            .vertex('shared/bufferless.vsh')
            .fragment('post/bloom/down.fsh')
            .target(0, texBloom, i)
            .define('TEX_SRC', i == 0 ? src : 'texBloom')
            .define('TEX_SCALE', Math.pow(2, i).toString())
            .define('BLOOM_INDEX', i.toString())
            .define('MIP_INDEX', Math.max(i-1, 0).toString())
            .build());
    }

    for (let i = maxLod-1; i >= 0; i--) {
        const shader = new Composite(`bloom-up-${i}`)
            .vertex('shared/bufferless.vsh')
            .fragment('post/bloom/up.fsh')
            .ubo(0, SceneSettingsBuffer)
            .define('TEX_SRC', src)
            .define('TEX_SCALE', Math.pow(2, i+1).toString())
            .define('BLOOM_INDEX', i.toString())
            .define('MIP_INDEX', i.toString());

        if (i == 0) {
            shader.target(0, target);
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
