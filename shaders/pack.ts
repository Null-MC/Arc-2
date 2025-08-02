import {BlockMap} from "./scripts/BlockMap";
import {BufferFlipper} from "./scripts/BufferFlipper";
import {StreamBufferBuilder} from "./scripts/StreamBufferBuilder";
import {ShaderBuilder} from "./scripts/ShaderBuilder";
import {TagBuilder, setLightColorEx, SSBO, UBO} from "./scripts/helpers";
import {LightingModes, ReflectionModes, ShaderSettings} from "./scripts/settings";


const LIGHT_BIN_SIZE = 8;
const QUAD_BIN_SIZE = 2;

const SceneSettingsBufferSize = 128;
let SceneSettingsBuffer: BuiltStreamingBuffer;
let BlockMappings: BlockMap;

let texFloodFill: undefined | BuiltTexture;
let texFloodFill_alt: undefined | BuiltTexture;
let texFloodFillReader: undefined | TextureReference;


// TODO: temp workaround
let renderConfig: RendererConfig;

export function configureRenderer(renderer : RendererConfig) {
    const settings = new ShaderSettings();
    const internal = settings.BuildInternalSettings(renderer);

    renderConfig = renderer;

    renderer.disableShade = true;
    renderer.ambientOcclusionLevel = 0.0;
    renderer.shadow.resolution = settings.Shadow_Resolution;
    renderer.shadow.cascades = settings.Shadow_CascadeCount;
    renderer.render.waterOverlay = false;
    renderer.render.stars = false;
    renderer.render.moon = false;
    renderer.render.sun = false;

    // TODO: fix hands later, for now just unbreak them
    renderer.mergedHandDepth = true;

    renderer.pointLight.nearPlane = internal.PointLightNear;
    renderer.pointLight.farPlane = internal.PointLightFar;
    renderer.pointLight.maxCount = settings.Lighting_Shadow_MaxCount;
    renderer.pointLight.resolution = settings.Lighting_Shadow_Resolution;
    renderer.pointLight.cacheRealTimeTerrain = false;

    applySettings(settings, internal);
}

function applySettings(settings : ShaderSettings, internal) {
    renderConfig.shadow.distance = settings.Shadow_Distance;

    renderConfig.pointLight.maxUpdates = settings.Lighting_Shadow_UpdateCount;
    renderConfig.pointLight.realTimeCount = settings.Lighting_Shadow_RealtimeCount;
    renderConfig.pointLight.updateThreshold = settings.Lighting_Shadow_UpdateThreshold * 0.01;

    renderConfig.shadow.enabled = (settings.Shadow_Enabled && internal.WorldHasSky) || !settings.Voxel_UseProvided;
    if (renderConfig.shadow.enabled) {
        if (settings.Shadow_CascadeCount == 1) {
            renderConfig.shadow.near = -200;
            renderConfig.shadow.far = 200;
        }
        else {
            renderConfig.shadow.near = -400;
            renderConfig.shadow.far = 400;
        }

        if (!settings.Voxel_UseProvided || internal.VoxelizeBlockFaces || internal.VoxelizeTriangles)
            renderConfig.shadow.safeZone[0] = settings.Voxel_Size / 2;
    }

    // define world-specific constants
    switch (renderConfig.dimension.getPath()) {
        case 'the_nether':
            defineGlobally1('WORLD_NETHER');
            break;
        case 'the_end':
            defineGlobally1('WORLD_END');
            defineGlobally1('WORLD_SKY_ENABLED');
            break;
        default:
            defineGlobally1('WORLD_OVERWORLD');
            defineGlobally1('WORLD_SKY_ENABLED');
            defineGlobally1('WORLD_SKYLIGHT_ENABLED');
            break;
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
    if (settings.Shadow_PcssEnabled) defineGlobally1('SHADOW_PCSS_ENABLED');
    if (settings.Shadow_CloudEnabled) defineGlobally1('SHADOWS_CLOUD_ENABLED');
    if (settings.Shadow_SS_Fallback) defineGlobally1('SHADOWS_SS_FALLBACK');
    defineGlobally('SHADOW_RESOLUTION', settings.Shadow_Resolution);
    defineGlobally('SHADOW_CASCADE_COUNT', settings.Shadow_CascadeCount);
    if (settings.Shadow_BlockerTexEnabled)
        defineGlobally1('SHADOW_BLOCKER_TEX');
    if (renderConfig.shadow.cascades == 1)
        defineGlobally1('SHADOW_DISTORTION_ENABLED');

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

    if (settings.Material_EntityTessellationEnabled)
        defineGlobally1('MATERIAL_ENTITY_TESSELLATION');

    if (settings.Material_FancyLava) {
        defineGlobally1('FANCY_LAVA');
        defineGlobally('FANCY_LAVA_RES', settings.Material_FancyLavaResolution);
    }

    defineGlobally('LIGHTING_MODE', settings.Lighting_Mode);
    defineGlobally('LIGHTING_VL_RES', settings.Lighting_VolumetricResolution);

    //defineGlobally('POINT_LIGHT_MAX', internal.PointLightMax);
    if (settings.Lighting_Mode == LightingModes.ShadowMaps) {
        //enableCubemapShadows(settings.Lighting_Shadow_Resolution, settings.Lighting_Shadow_MaxCount);

        defineGlobally('LIGHTING_SHADOW_RANGE', settings.Lighting_Shadow_Range);
        defineGlobally('LIGHTING_SHADOW_MAX_COUNT', settings.Lighting_Shadow_MaxCount);
        defineGlobally('LIGHTING_SHADOW_BIN_MAX_COUNT', settings.Lighting_Shadow_BinMaxCount);
        if (settings.Lighting_Shadow_PCSS)
            defineGlobally1('LIGHTING_SHADOW_PCSS');
        if (settings.Lighting_Shadow_EmissionMask)
            defineGlobally1('LIGHTING_SHADOW_EMISSION_MASK');
        if (settings.Lighting_Shadow_BinsEnabled)
            defineGlobally1('LIGHTING_SHADOW_BIN_ENABLED');
        if (settings.Lighting_Shadow_VoxelFill)
            defineGlobally1('LIGHTING_SHADOW_VOXEL_FILL');
    }

    if (settings.Lighting_VxGI_Enabled) {
        defineGlobally1('LIGHTING_GI_ENABLED');
        defineGlobally('VOXEL_GI_MAXSTEP', settings.Lighting_VxGI_MaxSteps);
        defineGlobally('WSGI_CASCADE_COUNT', settings.Lighting_VxGI_CascadeCount);
        defineGlobally('LIGHTING_GI_SIZE', settings.Lighting_VxGI_BufferSize);
        defineGlobally('VOXEL_GI_MAXFRAMES', settings.Lighting_VxGI_MaxFrames);

        if (settings.Lighting_VxGI_SkyLight)
            defineGlobally1('LIGHTING_GI_SKYLIGHT');

        defineGlobally('WSGI_SCALE_BASE', settings.Lighting_VxGI_BaseScale);

        // const scaleF = Math.max(settings.Lighting_GI_BaseScale + settings.Lighting_GI_CascadeCount - 2, 0);
        // const snapScale = Math.pow(2, scaleF);
        // defineGlobally("WSGI_SNAP_SCALE", snapScale);
    }

    if (settings.Lighting_Volumetric_ShadowsEnabled)
        defineGlobally1('LIGHTING_VL_SHADOWS');

    defineGlobally('LIGHTING_REFLECT_MODE', settings.Lighting_ReflectionMode);
    defineGlobally('LIGHTING_REFLECT_MAXSTEP', settings.Lighting_ReflectionStepCount)
    if (settings.Lighting_ReflectionNoise) defineGlobally1('MATERIAL_ROUGH_REFLECT_NOISE');
    if (settings.Lighting_ReflectionSsrFallback) defineGlobally1('LIGHTING_REFLECT_SRR_FALLBACK')
    if (settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        if (settings.Lighting_ReflectionQuads) defineGlobally1('LIGHTING_REFLECT_TRIANGLE');
    }

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

    if (internal.FloodFillEnabled) {
        defineGlobally1('FLOODFILL_ENABLED');
    }

    if (internal.LightListsEnabled) {
        defineGlobally1('LIGHT_LIST_ENABLED');
    }

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

export function configurePipeline(pipeline : PipelineConfig) {
    const renderer = pipeline.getRendererConfig();
    print(`Setting up shader [DIM: ${renderer.dimension.getPath()}]`);

    BlockMappings = new BlockMap();
    BlockMappings.map('end_portal', 'BLOCK_END_PORTAL');
    BlockMappings.map('grass_block', 'BLOCK_GRASS');
    BlockMappings.map('lava', 'BLOCK_LAVA');

    const settings = new ShaderSettings();
    const internal = settings.BuildInternalSettings(renderer);
    applySettings(settings, internal);

    const blockTags = new TagBuilder(pipeline)
        //.map("TAG_FOLIAGE", new NamespacedId("aperture", "foliage"))
        .map("TAG_LEAVES", new NamespacedId("minecraft", "leaves"))
        .map("TAG_STAIRS", new NamespacedId("minecraft", "stairs"))
        .map("TAG_SLABS", new NamespacedId("minecraft", "slabs"))
        .map("TAG_SNOW", new NamespacedId("minecraft", "snow"));

    blockTags.map('TAG_FOLIAGE_GROUND', pipeline.createTag(new NamespacedId('arc', 'foliage_ground'),
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

    blockTags.map('TAG_WAVING_FULL', pipeline.createTag(new NamespacedId('arc', 'waving_full'),
        new NamespacedId('birch_leaves'),
        new NamespacedId('cherry_leaves'),
        new NamespacedId('jungle_leaves'),
        new NamespacedId('mangrove_leaves'),
        new NamespacedId('oak_leaves'),
        new NamespacedId('dark_oak_leaves'),
        new NamespacedId('pale_oak_leaves'),
        new NamespacedId('spruce_leaves')));

    blockTags.map("TAG_CARPET", pipeline.createTag(new NamespacedId("arc", "carpets"),
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

    // blockTags.map("TAG_NON_POINT_LIGHT", pipeline.createTag(new NamespacedId("arc", "non_point_lights"),
    //     new NamespacedId("firefly_bush"),
    //     new NamespacedId("lava"),
    //     new NamespacedId("magma_block")));

    blockTags.map("TAG_TINTS_LIGHT", pipeline.createTag(new NamespacedId("arc", "tints_light"),
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

    blockTags.map("TAG_LIGHT_FLICKER", pipeline.createTag(new NamespacedId("arc", "light_flicker"),
        new NamespacedId("fire"),
        new NamespacedId("jack_o_lantern"),
        new NamespacedId("lantern"),
        new NamespacedId("torch"),
        new NamespacedId("wall_torch"),
        new NamespacedId("soul_torch"),
        new NamespacedId("soul_wall_torch")));

    setLightColorEx('#8053d1', 'amethyst_cluster');
    setLightColorEx('#3e2d1f', 'brown_mushroom');
    setLightColorEx('#f39849', 'campfire');
    setLightColorEx('#935b2c', 'cave_vines', "cave_vines_plant");
    setLightColorEx('#d39f6d', 'copper_bulb', 'waxed_copper_bulb');
    setLightColorEx('#d39255', 'exposed_copper_bulb', 'waxed_exposed_copper_bulb');
    setLightColorEx('#cf833a', 'weathered_copper_bulb', 'waxed_weathered_copper_bulb');
    setLightColorEx('#87480b', 'oxidized_copper_bulb', 'waxed_oxidized_copper_bulb');
    setLightColorEx('#7f17a8', 'crying_obsidian', 'respawn_anchor');
    setLightColorEx('#371559', 'enchanting_table');
    setLightColorEx('#ac9833', 'end_gateway');
    setLightColorEx('#5f33ac', 'end_portal');
    setLightColorEx('#bea935', 'firefly_bush');
    setLightColorEx('#5f9889', 'glow_lichen');
    setLightColorEx('#d3b178', 'glowstone');
    setLightColorEx('#c2985a', 'jack_o_lantern');
    setLightColorEx('#f39e49', 'lantern');
    setLightColorEx('#b8491c', 'lava', 'magma_block');
    setLightColorEx('#650a5e', 'nether_portal');
    setLightColorEx('#dfac47', 'ochre_froglight');
    setLightColorEx('#e075e8', 'pearlescent_froglight');
    setLightColorEx('#f9321c', 'redstone_torch', 'redstone_wall_torch');
    setLightColorEx('#e0ba42', 'redstone_lamp');
    setLightColorEx('#f9321c', 'redstone_ore', 'deepslate_redstone_ore');
    setLightColorEx('#8bdff8', 'sea_lantern');
    setLightColorEx('#4d9a76', 'sea_pickle');
    setLightColorEx('#918f34', 'shroomlight');
    setLightColorEx('#28aaeb', 'soul_torch', 'soul_wall_torch', 'soul_campfire');
    setLightColorEx('#f3b549', 'torch', 'wall_torch');
    setLightColorEx('#a61914', 'trial_spawner');
    setLightColorEx('#dfb906', 'vault');
    setLightColorEx('#63e53c', 'verdant_froglight');

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

    SceneSettingsBuffer = pipeline.createStreamingBuffer(SceneSettingsBufferSize);

    const dimension = renderConfig.dimension.getPath();

    pipeline.importRawTexture('texFogNoise', 'textures/fog.dat')
        .type(PixelType.UNSIGNED_BYTE)
        .format(Format.R8_SNORM)
        .width(256)
        .height(32)
        .depth(256)
        .clamp(false)
        .blur(true)
        .load();

    pipeline.importPNGTexture('texBlueNoise', 'textures/blue_noise.png', true, false);

    switch (dimension) {
        case 'the_end':
            pipeline.importPNGTexture('texEndSun', 'textures/end-sun.png', true, false);

            pipeline.importPNGTexture('texEarth', 'textures/earth.png', true, false);
            pipeline.importPNGTexture('texEarthSpecular', 'textures/earth-specular.png', true, false);
            break;
        default:
            pipeline.importPNGTexture('texMoon', 'textures/moon.png', true, false);
            //pipeline.importPNGTexture('texMoonNormal', 'textures/moon-normal.png', true, false);
            break;
    }

    const texShadowColor = pipeline.createArrayTexture('texShadowColor')
        .format(Format.RGBA8)
        .width(settings.Shadow_Resolution)
        .height(settings.Shadow_Resolution)
        .clear(false)
        .build();

    if (settings.Shadow_BlockerTexEnabled) {
        const texShadowBlocker = pipeline.createImageArrayTexture('texShadowBlocker', 'imgShadowBlocker')
            .format(Format.R16F)
            .width(settings.Shadow_Resolution / 2)
            .height(settings.Shadow_Resolution / 2)
            .clear(false)
            .build();
    }

    // const texGgxDfg = pipeline.createTexture('texGgxDfg')
    //     .format(Format.RG16F)
    //     .width(128)
    //     .height(128)
    //     .clear(false)
    //     .build();

    const texSkyTransmit = pipeline.createTexture('texSkyTransmit')
        .format(Format.RGB16F)
        .width(256)
        .height(64)
        .clear(false)
        .build();

    const texSkyMultiScatter = pipeline.createTexture('texSkyMultiScatter')
        .format(Format.RGB16F)
        .width(32)
        .height(32)
        .clear(false)
        .build();

    const texSkyView = pipeline.createTexture('texSkyView')
        .format(Format.RGB16F)
        .width(256)
        .height(256)
        .clear(false)
        .build();

    const texSkyIrradiance = pipeline.createTexture('texSkyIrradiance')
        .format(Format.RGB16F)
        .width(32)
        .height(32)
        .clear(false)
        .build();

    const texFinalA = pipeline.createTexture('texFinalA')
        .format(Format.RGB16F)
        .width(screenWidth)
        .height(screenHeight)
        .mipmap(true)
        .clear(!internal.WorldHasSky)
        .build();

    const texFinalB = pipeline.createTexture('texFinalB')
        .format(Format.RGB16F)
        .width(screenWidth)
        .height(screenHeight)
        .mipmap(true)
        .clear(!internal.WorldHasSky)
        .build();

    const finalFlipper = new BufferFlipper(
        'texFinalA', texFinalA,
        'texFinalB', texFinalB);

    const texFinalPrevious = pipeline.createTexture('texFinalPrevious')
        .format(Format.RGB16F)
        .width(screenWidth)
        .height(screenHeight)
        .mipmap(true)
        .clear(false)
        .build();

    const texParticleOpaque = pipeline.createTexture('texParticleOpaque')
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texParticleTranslucent = pipeline.createTexture('texParticleTranslucent')
        .format(Format.RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texGlint = pipeline.createTexture('texGlint')
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_Color = pipeline.createTexture('texDeferredOpaque_Color')
        .format(Format.RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_TexNormal = pipeline.createTexture('texDeferredOpaque_TexNormal')
        .format(Format.RGB16)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredOpaque_Data = pipeline.createTexture('texDeferredOpaque_Data')
        .format(Format.RGBA32UI)
        //.clearColor(0.0, 0.0, 0.0, 0.0)
        .clear(false)
        .width(screenWidth)
        .height(screenHeight)
        .build();

    const texDeferredTrans_Color = pipeline.createTexture('texDeferredTrans_Color')
        .format(Format.RGBA8)
        .width(screenWidth)
        .height(screenHeight)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build();

    const texDeferredTrans_TexNormal = pipeline.createTexture('texDeferredTrans_TexNormal')
        .format(Format.RGB16)
        .width(screenWidth)
        .height(screenHeight)
        .clear(false)
        .build();

    const texDeferredTrans_Data = pipeline.createTexture('texDeferredTrans_Data')
        .format(Format.RGBA32UI)
        .width(screenWidth)
        .height(screenHeight)
        .clear(false)
        .build();

    const texDeferredTrans_Depth = pipeline.createTexture('texDeferredTrans_Depth')
        .format(Format.R32F)
        .width(screenWidth)
        .height(screenHeight)
        .clearColor(1.0, 1.0, 1.0, 1.0)
        .build();

    let texShadow: BuiltTexture | undefined;
    let texShadow_final: BuiltTexture | undefined;
    if (settings.Shadow_Enabled || settings.Shadow_SS_Fallback) {
        texShadow = pipeline.createTexture('texShadow')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        texShadow_final = pipeline.createImageTexture('texShadow_final', 'imgShadow_final')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    if (!settings.Voxel_UseProvided) {
        pipeline.createImageTexture('texVoxelBlock', 'imgVoxelBlock')
            .format(Format.R32UI)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
            .clearColor(0.0, 0.0, 0.0, 0.0)
            .build();
    }

    let texDiffuseRT: BuiltTexture | undefined;
    let texSpecularRT: BuiltTexture | undefined;
    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        texDiffuseRT = pipeline.createTexture('texDiffuseRT')
            .format(Format.RGB16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();

        texSpecularRT = pipeline.createTexture('texSpecularRT')
            .format(Format.RGBA16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();
    }

    let texSSAO: BuiltTexture | undefined;
    let texSSAO_final: BuiltTexture | undefined;
    if (settings.Effect_SSAO_Enabled) {
        texSSAO = pipeline.createTexture('texSSAO')
            .format(Format.R16F)
            .width(screenWidth_half)
            .height(screenHeight_half)
            .clear(false)
            .build();

        texSSAO_final = pipeline.createImageTexture('texSSAO_final', 'imgSSAO_final')
            .format(Format.R16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    if (internal.Accumulation) {
        pipeline.createImageTexture('texAccumDiffuse_opaque', 'imgAccumDiffuse_opaque')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumDiffuse_opaque_alt', 'imgAccumDiffuse_opaque_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumDiffuse_translucent', 'imgAccumDiffuse_translucent')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumDiffuse_translucent_alt', 'imgAccumDiffuse_translucent_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumSpecular_opaque', 'imgAccumSpecular_opaque')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumSpecular_opaque_alt', 'imgAccumSpecular_opaque_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumSpecular_translucent', 'imgAccumSpecular_translucent')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumSpecular_translucent_alt', 'imgAccumSpecular_translucent_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumPosition_opaque', 'imgAccumPosition_opaque')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumPosition_opaque_alt', 'imgAccumPosition_opaque_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumPosition_translucent', 'imgAccumPosition_translucent')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texAccumPosition_translucent_alt', 'imgAccumPosition_translucent_alt')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        if (settings.Effect_SSAO_Enabled) {
            pipeline.createImageTexture('texAccumOcclusion_opaque', 'imgAccumOcclusion_opaque')
                .format(Format.RG16F)
                .width(screenWidth)
                .height(screenHeight)
                .clear(false)
                .build();

            pipeline.createImageTexture('texAccumOcclusion_opaque_alt', 'imgAccumOcclusion_opaque_alt')
                .format(Format.RG16F)
                .width(screenWidth)
                .height(screenHeight)
                .clear(false)
                .build();
        }
    }

    const vlScale = Math.pow(2, settings.Lighting_VolumetricResolution);
    const vlWidth = Math.ceil(screenWidth / vlScale);
    const vlHeight = Math.ceil(screenHeight / vlScale);

    const texScatterVL = pipeline.createTexture('texScatterVL')
        .format(Format.RGB16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(false)
        .build();

    const texTransmitVL = pipeline.createTexture('texTransmitVL')
        .format(Format.RGB16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(false)
        .build();

    pipeline.createImageTexture('texScatterFiltered', 'imgScatterFiltered')
        .format(Format.RGBA16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(true) // TODO: shouldn't need clearing but avoids bug
        .build();

    pipeline.createImageTexture('texTransmitFiltered', 'imgTransmitFiltered')
        .format(Format.RGBA16F)
        .width(vlWidth)
        .height(vlHeight)
        .clear(true) // TODO: shouldn't need clearing but avoids bug
        .build();

    if (settings.Lighting_VolumetricResolution > 0) {
        pipeline.createImageTexture('texScatterFinal', 'imgScatterFinal')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();

        pipeline.createImageTexture('texTransmitFinal', 'imgTransmitFinal')
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    let vxgiBuffer: BuiltBuffer | undefined;
    let vxgiBuffer_alt: BuiltBuffer | undefined;
    if (settings.Lighting_VxGI_Enabled) {
        // f16vec4[3] * VoxelBufferSize^3
        const bufferSize = 48 * cubed(settings.Lighting_VxGI_BufferSize) * settings.Lighting_VxGI_CascadeCount;

        vxgiBuffer = pipeline.createBuffer(bufferSize, false);

        vxgiBuffer_alt = pipeline.createBuffer(bufferSize, false);
    }

    if (internal.FloodFillEnabled) {
        texFloodFill = pipeline.createImageTexture('texFloodFill', 'imgFloodFill')
            .format(Format.RGBA16F)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
            .clear(false)
            .build();

        texFloodFill_alt = pipeline.createImageTexture('texFloodFill_alt', 'imgFloodFill_alt')
            .format(Format.RGBA16F)
            .width(settings.Voxel_Size)
            .height(settings.Voxel_Size)
            .depth(settings.Voxel_Size)
            .clear(false)
            .build();

        texFloodFillReader = pipeline.createTextureReference("texFloodFill_final", null, settings.Voxel_Size, settings.Voxel_Size, settings.Voxel_Size, Format.RGBA16F);
    }

    const texHistogram = pipeline.createImageTexture('texHistogram', 'imgHistogram')
        .format(Format.R32UI)
        .width(256)
        .height(1)
        .clear(false)
        .build();

    if (settings.Debug_Exposure) {
        const texHistogram_debug = pipeline.createImageTexture('texHistogram_debug', 'imgHistogram_debug')
            .format(Format.R32UI)
            .width(256)
            .height(1)
            .clear(false)
            .build();
    }

    let texTaaPrev: BuiltTexture | undefined;
    if (settings.Post_TAA_Enabled) {
        texTaaPrev = pipeline.createTexture("texTaaPrev")
            .format(Format.RGBA16F)
            .width(screenWidth)
            .height(screenHeight)
            .clear(false)
            .build();
    }

    const sceneBuffer = pipeline.createBuffer(1024, false);

    let lightListBuffer: BuiltBuffer | undefined;
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

        lightListBuffer = pipeline.createBuffer(lightListBufferSize, false);
    }
    else if (settings.Debug_LightCount) {
        lightListBuffer = pipeline.createBuffer(4, false);
    }

    let blockFaceBuffer: BuiltBuffer | undefined;
    if (internal.VoxelizeBlockFaces) {
        const bufferSize = 6 * 8 * cubed(settings.Voxel_Size);

        blockFaceBuffer = pipeline.createBuffer(bufferSize, false);
    }

    let quadListBuffer: BuiltBuffer | undefined;
    if (internal.VoxelizeTriangles) {
        const quadBinSize = 4 + 40*settings.Voxel_MaxQuadCount;
        const quadListBinCount = Math.ceil(settings.Voxel_Size / QUAD_BIN_SIZE);
        const quadListBufferSize = quadBinSize * cubed(quadListBinCount) + 4;
        print(`Quad-List Buffer Size: ${quadListBufferSize.toLocaleString()}`);

        // TODO: clear with compute
        quadListBuffer = pipeline.createBuffer(quadListBufferSize, true);
    }

    const screenSetupQueue = pipeline.forStage(Stage.SCREEN_SETUP);

    // screenSetupQueue.createComposite('ggx-dfg')
    //     .vertex('shared/bufferless.vsh')
    //     .fragment('setup/ggx-dfg.fsh')
    //     .target(0, texGgxDfg)
    //     .compile();

    new ShaderBuilder(screenSetupQueue.createCompute('scene-setup')
            .location('setup/scene-setup.csh')
            .workGroups(1, 1, 1)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .compile();

    screenSetupQueue.createCompute('histogram-clear')
        .location('setup/histogram-clear.csh')
        .workGroups(1, 1, 1)
        .compile();

    if (settings.Lighting_VxGI_Enabled) {
        new ShaderBuilder(screenSetupQueue.createCompute('wsgi-clear')
                .location('setup/wsgi-clear.csh')
                .workGroups(8, 8, 8)
            )
            .ssbo(SSBO.VxGI, vxgiBuffer)
            .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt)
            .compile();
    }

    new ShaderBuilder(screenSetupQueue.createComposite('sky-transmit')
            .vertex('shared/bufferless.vsh')
            .fragment('setup/sky_transmit.fsh')
            .target(0, texSkyTransmit)
        )
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    new ShaderBuilder(screenSetupQueue.createComposite('sky-multi-scatter')
            .vertex('shared/bufferless.vsh')
            .fragment('setup/sky_multi_scatter.fsh')
            .target(0, texSkyMultiScatter)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    screenSetupQueue.end();

    const preRenderQueue = pipeline.forStage(Stage.PRE_RENDER);

    if (internal.LightListsEnabled) {
        const binCount = Math.ceil(settings.Voxel_Size / LIGHT_BIN_SIZE);
        const groupCount = Math.ceil(binCount / 8);

        print(`light list clear bounds: [${groupCount}]^3`);

        new ShaderBuilder(preRenderQueue.createCompute('light-list-clear')
                .location('setup/light-list-clear.csh')
                .workGroups(groupCount, groupCount, groupCount)
            )
            .ssbo(SSBO.LightList, lightListBuffer)
            .compile();
    }

    new ShaderBuilder(preRenderQueue.createCompute('scene-prepare')
            .location('setup/scene-prepare.csh')
            .workGroups(1, 1, 1)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ssbo(SSBO.LightList, lightListBuffer)
        .ssbo(SSBO.QuadList, quadListBuffer)
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    // IMAGE_BIT | SSBO_BIT | UBO_BIT | FETCH_BIT
    preRenderQueue.barrier(SSBO_BIT);

    if (internal.WorldHasSky) {
        new ShaderBuilder(preRenderQueue.createComposite('sky-view')
                .vertex('shared/bufferless.vsh')
                .fragment('setup/sky_view.fsh')
                .target(0, texSkyView)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();

        new ShaderBuilder(preRenderQueue.createComposite('sky-irradiance')
                .vertex("shared/bufferless.vsh")
                .fragment("setup/sky_irradiance.fsh")
                .target(0, texSkyIrradiance)
                .blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    //pipeline.addBarrier(Stage.PRE_RENDER, IMAGE_BIT);

    new ShaderBuilder(preRenderQueue.createCompute('scene-begin')
            .location('setup/scene-begin.csh')
            .workGroups(1, 1, 1)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .compile();

    preRenderQueue.barrier(SSBO_BIT);

    preRenderQueue.end();

    function shadowShader(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return new ShaderBuilder(pipeline.createObjectShader(name, usage)
                .vertex('gbuffer/shadow-celestial.vsh')
                .fragment('gbuffer/shadow-celestial.fsh')
                .target(0, texShadowColor)
                .define('RENDER_SHADOW', '1')
            )
            .ssbo(SSBO.Scene, sceneBuffer);
    }

    function shadowTerrainShader(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return shadowShader(name, usage)
            .if(internal.VoxelizeBlockFaces || internal.VoxelizeTriangles || !settings.Voxel_UseProvided, builder => builder
                .with(s => s.geometry('gbuffer/shadow-celestial.gsh')))
            .with(shader => shader
                .define('RENDER_TERRAIN', '1'))
            .ssbo(SSBO.LightList, lightListBuffer)
            .if(internal.VoxelizeBlockFaces, builder => builder
                .ssbo(SSBO.BlockFace, blockFaceBuffer))
            .if(internal.VoxelizeTriangles, builder => builder
                .ssbo(SSBO.QuadList, quadListBuffer));
    }

    function shadowEntityShader(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return shadowShader(name, usage)
            .with(shader => shader
                .define('RENDER_ENTITY', '1'))
            .if(internal.VoxelizeTriangles, builder => builder
                .with(s => s.geometry('gbuffer/shadow-celestial.gsh'))
                .ssbo(SSBO.QuadList, quadListBuffer));
    }

    if (settings.Shadow_Enabled) {
        shadowShader('shadow', Usage.SHADOW).compile();

        shadowTerrainShader('shadow-terrain-solid', Usage.SHADOW_TERRAIN_SOLID).compile();

        shadowTerrainShader('shadow-terrain-cutout', Usage.SHADOW_TERRAIN_CUTOUT).compile();

        shadowTerrainShader('shadow-terrain-translucent', Usage.SHADOW_TERRAIN_TRANSLUCENT)
            .with(s => s.define('RENDER_TRANSLUCENT', '1'))
            .compile();

        shadowEntityShader('shadow-entity-solid', Usage.SHADOW_ENTITY_SOLID).compile();

        shadowEntityShader('shadow-entity-cutout', Usage.SHADOW_ENTITY_CUTOUT).compile();

        shadowEntityShader('shadow-entity-translucent', Usage.SHADOW_ENTITY_TRANSLUCENT)
            .with(s => s.define('RENDER_TRANSLUCENT', '1'))
            .compile();
    }

    if (settings.Lighting_Mode == LightingModes.ShadowMaps) {
        pipeline.createObjectShader('block-shadow', Usage.POINT)
            .vertex("gbuffer/shadow-point.vsh")
            .fragment("gbuffer/shadow-point.fsh")
            .compile();
    }

    const postShadowQueue = pipeline.forStage(Stage.POST_SHADOW);

    function shadowBlockerShader(layer: number) {
        const blockerGroupSize = settings.Shadow_Resolution/32;

        return postShadowQueue.createCompute(`shadow-blocker-${layer}`)
            .location('composite/shadow-blocker.csh')
            .workGroups(blockerGroupSize, blockerGroupSize, 1)
            .define('SHADOW_LAYER', layer.toString());
    }

    if (settings.Shadow_Enabled && settings.Shadow_BlockerTexEnabled) {
        for (let l = 0; l < settings.Shadow_CascadeCount; l++)
            shadowBlockerShader(l).compile();
    }

    if (settings.Lighting_Mode == LightingModes.ShadowMaps && settings.Lighting_Shadow_BinsEnabled) {
        const pointGroupCount = Math.ceil(settings.Lighting_Shadow_MaxCount / (8*8*8));
        const voxelGroupCount = Math.ceil(settings.Voxel_Size / 8);

        new ShaderBuilder(postShadowQueue.createCompute('light-list-point')
                .location('composite/light-list-shadow.csh')
                .workGroups(pointGroupCount, pointGroupCount, pointGroupCount)
            )
            .ssbo(SSBO.LightList, lightListBuffer)
            .compile();

        postShadowQueue.barrier(SSBO_BIT);

        new ShaderBuilder(postShadowQueue.createCompute('light-list-neighbors')
                .location('composite/light-list-shadow-neighbors.csh')
                .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
            )
            .ssbo(SSBO.LightList, lightListBuffer)
            .compile();

        if (settings.Lighting_Shadow_VoxelFill) {
            postShadowQueue.barrier(SSBO_BIT);

            new ShaderBuilder(postShadowQueue.createCompute('light-list-voxel')
                    .location('composite/light-list-voxel.csh')
                    .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
                )
                .ssbo(SSBO.LightList, lightListBuffer)
                .compile();

            postShadowQueue.barrier(SSBO_BIT);

            new ShaderBuilder(postShadowQueue.createCompute('light-list-voxel-neighbors')
                    .location('composite/light-list-voxel-neighbors.csh')
                    .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
                )
                .ssbo(SSBO.LightList, lightListBuffer)
                .compile();
        }
    }
    else if (settings.Lighting_Mode == LightingModes.RayTraced) {
        const voxelGroupCount = Math.ceil(settings.Voxel_Size / 8);

        new ShaderBuilder(postShadowQueue.createCompute('light-list')
                .location('composite/light-list.csh')
                .workGroups(voxelGroupCount, voxelGroupCount, voxelGroupCount)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ssbo(SSBO.LightList, lightListBuffer)
            .compile();
    }

    if (internal.FloodFillEnabled) {
        const groupCount = Math.ceil(settings.Voxel_Size / 8);

        new ShaderBuilder(postShadowQueue.createCompute('floodfill')
                .location('composite/floodfill.csh')
                .workGroups(groupCount, groupCount, groupCount)
                .define('RENDER_COMPUTE', '1')
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    postShadowQueue.end();

    function DiscardObjectShader(name: string, usage: ProgramUsage) {
        return pipeline.createObjectShader(name, usage)
            .vertex("shared/discard.vsh")
            .fragment("shared/noop.fsh")
            .define("RENDER_GBUFFER", "1");
    }

    DiscardObjectShader("skybox", Usage.SKYBOX)
        .target(0, texFinalA)
        .compile();

    DiscardObjectShader("sky-texture", Usage.SKY_TEXTURES)
        .target(0, texFinalA)
        .compile();

    DiscardObjectShader("clouds", Usage.CLOUDS)
        .target(0, texFinalA)
        .compile();

    function _mainShader(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return new ShaderBuilder(pipeline.createObjectShader(name, usage)
            .vertex("gbuffer/main.vsh")
            .fragment("gbuffer/main.fsh"));
    }

    function mainShaderOpaque(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return _mainShader(name, usage).with(shader => shader
            .target(0, texDeferredOpaque_Color)
            // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
            .target(1, texDeferredOpaque_TexNormal)
            .blendOff(1)
            .target(2, texDeferredOpaque_Data)
            .blendOff(2));
    }

    function mainShaderTranslucent(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return _mainShader(name, usage).with(shader => shader
            .target(0, texDeferredTrans_Color)
            // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
            .target(1, texDeferredTrans_TexNormal)
            .blendOff(1)
            .target(2, texDeferredTrans_Data)
            .blendOff(2)
            .target(3, texDeferredTrans_Depth)
            .blendOff(3)
            .define('RENDER_TRANSLUCENT', '1'));
    }

    pipeline.createObjectShader('crumbling', Usage.CRUMBLING)
        .vertex('gbuffer/crumbling.vsh')
        .fragment('gbuffer/crumbling.fsh')
        .target(0, texDeferredOpaque_Color)
        .compile();

    // TODO: outline not yet supported
    // registerShader(new ObjectShader("lines", Usage.LINES)
    //     .vertex("gbuffer/lines.vsh")
    //     .fragment("gbuffer/lines.fsh")
    //     .target(0, texDeferredOpaque_Color)
    //     .target(1, texDeferredOpaque_TexNormal)
    //     .blendOff(1)
    //     .target(2, texDeferredOpaque_Data)
    //     .blendOff(2)
    //     .build());

    mainShaderOpaque('emissive', Usage.EMISSIVE)
        .with(s => s.define('RENDER_EMISSIVE', '1'))
        .compile();

    pipeline.createObjectShader('glint', Usage.ENTITY_GLINT)
        .vertex("gbuffer/glint.vsh")
        .fragment("gbuffer/glint.fsh")
        .target(0, texGlint)
        .blendOff(0)
        .compile();

    mainShaderOpaque('basic', Usage.BASIC)
        .compile();

    mainShaderOpaque('terrain-solid', Usage.TERRAIN_SOLID)
        .with(s => s.define('RENDER_TERRAIN', '1'))
        .compile();

    mainShaderOpaque('terrain-cutout', Usage.TERRAIN_CUTOUT)
        .with(s => s.define('RENDER_TERRAIN', '1'))
        .compile();

    mainShaderTranslucent('terrain-translucent', Usage.TERRAIN_TRANSLUCENT)
        .with(s => s.define('RENDER_TERRAIN', '1'))
        .if(settings.Water_WaveEnabled && settings.Water_TessellationEnabled, builder => builder
            .with(shader => shader
                .control('gbuffer/main.tcs')
                .eval('gbuffer/main.tes')))
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    mainShaderOpaque('hand-solid', Usage.HAND)
        .with(s => s.define('RENDER_HAND', '1'))
        .compile();

    mainShaderTranslucent('hand-translucent', Usage.TRANSLUCENT_HAND)
        .with(s => s.define('RENDER_HAND', '1'))
        .compile();

    // mainShaderOpaque('block-solid', Usage.BLOCK_ENTITY)
    //     .with(s => s.define('RENDER_BLOCK', '1'))
    //     .compile();
    //
    // mainShaderTranslucent('block-translucent', Usage.BLOCK_ENTITY_TRANSLUCENT)
    //     .with(s => s.define('RENDER_BLOCK', '1'))
    //     .compile();

    mainShaderOpaque('entity-solid', Usage.ENTITY_SOLID)
        .with(s => s.define('RENDER_ENTITY', '1'))
        .if(settings.Material_EntityTessellationEnabled, builder => builder
            .with(shader => shader
                .control('gbuffer/main.tcs')
                .eval('gbuffer/main.tes')))
        .compile();

    mainShaderOpaque('entity-cutout', Usage.ENTITY_CUTOUT)
        .with(s => s.define('RENDER_ENTITY', '1'))
        .if(settings.Material_EntityTessellationEnabled, builder => builder
            .with(shader => shader
                .control('gbuffer/main.tcs')
                .eval('gbuffer/main.tes')))
        .compile();

    mainShaderTranslucent('entity-translucent', Usage.ENTITY_TRANSLUCENT)
        .with(s => s.define('RENDER_ENTITY', '1'))
        .if(settings.Material_EntityTessellationEnabled, builder => builder
            .with(shader => shader
                .control('gbuffer/main.tcs')
                .eval('gbuffer/main.tes')))
        .compile();

    function particleShader(name: string, usage: ProgramUsage) : ShaderBuilder<ObjectShader, BuiltObjectShader> {
        return new ShaderBuilder(pipeline.createObjectShader(name, usage)
                .vertex('gbuffer/particles.vsh')
                .fragment('gbuffer/particles.fsh')
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .if(settings.Lighting_VxGI_Enabled, builder => builder
                .ssbo(SSBO.VxGI, vxgiBuffer)
                .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt))
            .if(internal.LightListsEnabled, builder => builder
                .ssbo(SSBO.LightList, lightListBuffer))
            .ubo(UBO.SceneSettings, SceneSettingsBuffer);
    }

    particleShader('particle-opaque', Usage.PARTICLES)
        .with(shader => shader
            .target(0, texParticleOpaque)
            .blendOff(0))
        .compile();

    particleShader('particle-translucent', Usage.PARTICLES_TRANSLUCENT)
        .with(shader => shader
            .target(0, texParticleTranslucent)
            .blendOff(0)
            .define('RENDER_TRANSLUCENT', '1'))
        .compile();

    new ShaderBuilder(pipeline.createObjectShader('weather', Usage.WEATHER)
            .vertex('gbuffer/weather.vsh')
            .fragment('gbuffer/weather.fsh')
            .target(0, texParticleTranslucent)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .if(internal.LightListsEnabled, builder => builder
            .ssbo(SSBO.LightList, lightListBuffer))
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    const postRenderQueue = pipeline.forStage(Stage.POST_RENDER);

    if (settings.Lighting_VxGI_Enabled) {
        const groupCount = Math.ceil(settings.Lighting_VxGI_BufferSize / 4);

        const giQueue = postRenderQueue.subList('global-illumination');

        for (let i = settings.Lighting_VxGI_CascadeCount-1; i >= 0; i--) {
            // if (internal.LightListsEnabled) {
            //     registerBarrier(Stage.POST_RENDER, new MemoryBarrier(SSBO_BIT));
            // }

            giQueue.barrier(SSBO_BIT);

            new ShaderBuilder(giQueue.createCompute(`global-illumination-${i+1}`)
                    .location('composite/global-illumination.csh')
                    .workGroups(groupCount, groupCount, groupCount)
                    .define('RENDER_COMPUTE', '1')
                    .define('WSGI_VOXEL_SCALE', (i + settings.Lighting_VxGI_BaseScale).toString())
                    .define('WSGI_CASCADE', i.toString())
                )
                .ssbo(SSBO.Scene, sceneBuffer)
                .ssbo(SSBO.VxGI, vxgiBuffer)
                .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt)
                .ssbo(SSBO.BlockFace, blockFaceBuffer)
                .if(internal.LightListsEnabled, builder => builder
                    .ssbo(SSBO.LightList, lightListBuffer))
                .ubo(UBO.SceneSettings, SceneSettingsBuffer)
                .compile();
        }

        giQueue.end();
    }

    if (internal.WorldHasSky && (settings.Shadow_Enabled || settings.Shadow_SS_Fallback)) {
        new ShaderBuilder(postRenderQueue.createComposite('shadow-opaque')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/shadow-opaque.fsh')
                .target(0, texShadow)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .compile();

        if (settings.Shadow_Filter) {
            new ShaderBuilder(postRenderQueue.createCompute('shadow-opaque-filter')
                    .location('composite/shadow-opaque-filter.csh')
                    .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
                )
                .compile();

            //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        }
    }

    const texShadow_src = settings.Shadow_Filter ? "texShadow_final" : "texShadow";

    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        postRenderQueue.barrier(SSBO_BIT);

        new ShaderBuilder(postRenderQueue.createComposite('rt-opaque')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/rt.fsh')
                .target(0, texDiffuseRT)
                .target(1, texSpecularRT)
                .define('TEX_DEFERRED_COLOR', 'texDeferredOpaque_Color')
                .define('TEX_DEFERRED_DATA', 'texDeferredOpaque_Data')
                .define('TEX_DEFERRED_NORMAL', 'texDeferredOpaque_TexNormal')
                .define('TEX_DEPTH', 'solidDepthTex')
                .define('TEX_SHADOW', texShadow_src)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ssbo(SSBO.QuadList, quadListBuffer)
            .ssbo(SSBO.BlockFace, blockFaceBuffer)
            .if(internal.LightListsEnabled, builder => builder
                .ssbo(SSBO.LightList, lightListBuffer))
            .if(settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace && settings.Lighting_VxGI_Enabled, builder => builder
                .ssbo(SSBO.VxGI, vxgiBuffer)
                .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt))
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    if (settings.Effect_SSAO_Enabled) {
        new ShaderBuilder(postRenderQueue.createComposite('ssao-opaque')
                .vertex("shared/bufferless.vsh")
                .fragment("composite/ssao.fsh")
                .target(0, texSSAO)
            )
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();

        // registerShader(Stage.POST_RENDER, new Compute("ssao-filter-opaque")
        //     // .barrier(true)
        //     .location("composite/ssao-filter-opaque.csh")
        //     .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        //     .build());
    }

    if (internal.Accumulation) {
        postRenderQueue.createCompute("accumulation-opaque")
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
            .compile();
    }

    new ShaderBuilder(postRenderQueue.createComposite('volumetric-far')
            .vertex('shared/bufferless.vsh')
            .fragment('composite/volumetric-far.fsh')
            .target(0, texScatterVL)
            .target(1, texTransmitVL)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .if(internal.LightListsEnabled, builder => builder
            .ssbo(SSBO.LightList, lightListBuffer))
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    postRenderQueue.barrier(SSBO_BIT | IMAGE_BIT);

    if (internal.WorldHasSky) {
        new ShaderBuilder(postRenderQueue.createComposite('sky')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/sky.fsh')
                .target(0, finalFlipper.getWriteTexture())
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    finalFlipper.flip();

    new ShaderBuilder(postRenderQueue.createComposite('composite-opaque')
            .vertex('shared/bufferless.vsh')
            .fragment('composite/composite-opaque.fsh')
            .target(0, finalFlipper.getWriteTexture())
            //.blendFunc(0, Func.SRC_ALPHA, Func.ONE_MINUS_SRC_ALPHA, Func.ONE, Func.ZERO)
            .define('TEX_SRC', finalFlipper.getReadName())
            .define('TEX_SHADOW', texShadow_src)
            .define('TEX_SSAO', 'texSSAO_final')
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ssbo(SSBO.QuadList, quadListBuffer)
        .ssbo(SSBO.BlockFace, blockFaceBuffer)
        .if(settings.Lighting_Mode == LightingModes.ShadowMaps, builder => builder
            .ssbo(SSBO.LightList, lightListBuffer))
        .if(settings.Lighting_VxGI_Enabled, builder => builder
            .ssbo(SSBO.VxGI, vxgiBuffer)
            .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt))
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    finalFlipper.flip();

    if (settings.Lighting_Mode == LightingModes.RayTraced || settings.Lighting_ReflectionMode == ReflectionModes.WorldSpace) {
        postRenderQueue.barrier(SSBO_BIT);

        new ShaderBuilder(postRenderQueue.createComposite('rt-translucent')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/rt.fsh')
                .target(0, texDiffuseRT)
                .target(1, texSpecularRT)
                .define('RENDER_TRANSLUCENT', '1')
                .define('TEX_DEFERRED_COLOR', 'texDeferredTrans_Color')
                .define('TEX_DEFERRED_DATA', 'texDeferredTrans_Data')
                .define('TEX_DEFERRED_NORMAL', 'texDeferredTrans_TexNormal')
                .define('TEX_DEPTH', 'mainDepthTex')
                .define('TEX_SHADOW', texShadow_src)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ssbo(SSBO.VxGI, vxgiBuffer)
            .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt)
            .ssbo(SSBO.LightList, lightListBuffer)
            .ssbo(SSBO.QuadList, quadListBuffer)
            .ssbo(SSBO.BlockFace, blockFaceBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    if (internal.Accumulation) {
        postRenderQueue.createCompute('accumulation-translucent')
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
            .compile();
    }

    const vlNearStage = postRenderQueue.subList('VL-near');

    if (renderConfig.dimension.getPath() == 'the_nether') {
        new ShaderBuilder(vlNearStage.createComposite('volumetric-near-nether')
                .vertex('shared/bufferless.vsh')
                .fragment('nether/volumetric-near.fsh')
                .target(0, texScatterVL)
                .target(1, texTransmitVL)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .if(internal.LightListsEnabled, builder => builder
                .ssbo(SSBO.LightList, lightListBuffer))
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }
    else {
        new ShaderBuilder(vlNearStage.createComposite('volumetric-near')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/volumetric-near.fsh')
                .target(0, texScatterVL)
                .target(1, texTransmitVL)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .if(internal.LightListsEnabled, builder => builder
                .ssbo(SSBO.LightList, lightListBuffer))
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    vlNearStage.barrier(IMAGE_BIT);

    vlNearStage.createCompute('volumetric-near-filter')
        .location('composite/volumetric-filter.csh')
        .workGroups(Math.ceil(vlWidth / 16.0), Math.ceil(vlHeight / 16.0), 1)
        .define('TEX_SCATTER', 'texScatterVL')
        .define('TEX_TRANSMIT', 'texTransmitVL')
        .define('TEX_DEPTH', 'mainDepthTex')
        .compile();

    vlNearStage.barrier(IMAGE_BIT);

    if (settings.Lighting_VolumetricResolution > 0) {
        vlNearStage.createCompute('volumetric-near-upscale')
            .location('composite/volumetric-upscale.csh')
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define('TEX_SCATTER', 'texScatterFiltered')
            .define('TEX_TRANSMIT', 'texTransmitFiltered')
            .define('TEX_DEPTH', 'mainDepthTex')
            .compile();

        vlNearStage.barrier(IMAGE_BIT | FETCH_BIT);
    }

    vlNearStage.end();

    postRenderQueue.generateMips(finalFlipper.getReadTexture());

    if (internal.WorldHasSky && (settings.Shadow_Enabled || settings.Shadow_SS_Fallback)) {
        new ShaderBuilder(postRenderQueue.createComposite('shadow-translucent')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/shadow-translucent.fsh')
                .target(0, texShadow)
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .compile();

        // if (snapshot.Shadow_Filter) {
        //     registerShader(Stage.POST_RENDER, new Compute("shadow-translucent-filter")
        //         .location("composite/shadow-opaque-filter.csh")
        //         .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        //         .build());
        //
        //     //registerBarrier(Stage.POST_RENDER, new MemoryBarrier(IMAGE_BIT));
        // }
    }

    new ShaderBuilder(postRenderQueue.createComposite('composite-translucent')
            .vertex('shared/bufferless.vsh')
            .fragment('composite/composite-translucent.fsh')
            .target(0, finalFlipper.getWriteTexture())
            .define('TEX_SRC', finalFlipper.getReadName())
            .define('TEX_SHADOW', 'texShadow')
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ssbo(SSBO.QuadList, quadListBuffer)
        .ssbo(SSBO.BlockFace, blockFaceBuffer)
        .if(settings.Lighting_Mode == LightingModes.ShadowMaps, builder => builder
            .ssbo(SSBO.LightList, lightListBuffer))
        .if(settings.Lighting_VxGI_Enabled, builder => builder
            .ssbo(SSBO.VxGI, vxgiBuffer)
            .ssbo(SSBO.VxGI_alt, vxgiBuffer_alt))
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

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

    postRenderQueue.copy(finalFlipper.getReadTexture(), texFinalPrevious, screenWidth, screenHeight);

    postRenderQueue.generateMips(texFinalPrevious);

    postRenderQueue.createComposite('blur-near')
        .vertex('shared/bufferless.vsh')
        .fragment('post/blur-near.fsh')
        .target(0, finalFlipper.getWriteTexture())
        .define('TEX_SRC', finalFlipper.getReadName())
        .compile();

    finalFlipper.flip();

    if (settings.Effect_DOF_Enabled) {
        postRenderQueue.generateMips(finalFlipper.getReadTexture());

        new ShaderBuilder(postRenderQueue.createComposite('depth-of-field')
                .vertex('shared/bufferless.vsh')
                .fragment('composite/depth-of-field.fsh')
                .target(0, finalFlipper.getWriteTexture())
                .define('TEX_SRC', finalFlipper.getReadName())
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();

        finalFlipper.flip();
    }

    const postProcessQueue = postRenderQueue.subList('post-processing');

    new ShaderBuilder(postProcessQueue.createCompute('histogram')
            .location('post/histogram.csh')
            .workGroups(Math.ceil(screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
            .define('TEX_SRC', finalFlipper.getReadName())
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    postProcessQueue.barrier(IMAGE_BIT);

    new ShaderBuilder(postProcessQueue.createCompute('exposure')
            .location('post/exposure.csh')
            .workGroups(1, 1, 1)
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    if (settings.Effect_Bloom_Enabled) {
        setupBloom(pipeline, postProcessQueue, finalFlipper.getReadName(), finalFlipper.getWriteTexture());

        finalFlipper.flip();
    }

    new ShaderBuilder(postProcessQueue.createComposite('tone-map')
            .vertex('shared/bufferless.vsh')
            .fragment('post/tonemap.fsh')
            .target(0, finalFlipper.getWriteTexture())
            .define('TEX_SRC', finalFlipper.getReadName())
        )
        .ssbo(SSBO.Scene, sceneBuffer)
        .ubo(UBO.SceneSettings, SceneSettingsBuffer)
        .compile();

    finalFlipper.flip();

    if (settings.Post_TAA_Enabled) {
        postProcessQueue.barrier(FETCH_BIT);

        postProcessQueue.createComposite('TAA')
            .vertex('shared/bufferless.vsh')
            .fragment('post/taa.fsh')
            .target(0, texTaaPrev)
            .target(1, finalFlipper.getWriteTexture())
            //.blendOff(1)
            .define('TEX_SRC', finalFlipper.getReadName())
            .compile();

        postProcessQueue.barrier(FETCH_BIT);

        finalFlipper.flip();
    }

    postProcessQueue.end();

    if (internal.DebugEnabled) {
        new ShaderBuilder(postRenderQueue.createComposite('debug')
                .vertex('shared/bufferless.vsh')
                .fragment('post/debug.fsh')
                .target(0, finalFlipper.getWriteTexture())
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
            )
            .ssbo(SSBO.Scene, sceneBuffer)
            .ssbo(SSBO.LightList, lightListBuffer)
            .ssbo(SSBO.QuadList, quadListBuffer)
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();

        finalFlipper.flip();
    }

    postRenderQueue.end();

    pipeline.createCombinationPass('post/final.fsh')
        .define('TEX_SRC', finalFlipper.getReadName())
        .compile();

    onSettingsChanged(pipeline);
    //setupFrame(null);
}

export function onSettingsChanged(pipeline: PipelineConfig) {
    const settings = new ShaderSettings();

    //const renderer = pipeline.getRendererConfig();
    renderConfig.sunPathRotation = settings.Sky_SunAngle;

    renderConfig.pointLight.realTimeCount = settings.Lighting_Shadow_RealtimeCount;
    renderConfig.pointLight.maxUpdates = settings.Lighting_Shadow_UpdateCount;
    renderConfig.pointLight.updateThreshold = settings.Lighting_Shadow_UpdateThreshold * 0.01;

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

export function beginFrame(state : WorldState) {
    const settings = new ShaderSettings();
    const internal = settings.BuildInternalSettings(renderConfig);

    // if (isKeyDown(Keys.G)) testVal += 0.07;
    // if (isKeyDown(Keys.F)) testVal -= 0.07;
    // TEST_UBO.setFloat(0, testVal);

    if (internal.FloodFillEnabled && texFloodFillReader)
        texFloodFillReader.pointTo(state.currentFrame() % 2 == 0 ? texFloodFill_alt : texFloodFill);

    SceneSettingsBuffer.uploadData();
}

export function getBlockId(block: BlockState) : number {
    const name = block.getName();
    const meta = BlockMappings.get(name);
    if (meta) return meta.index;

    return 0;
}

function setupBloom(pipeline: PipelineConfig, postRenderStage: CommandList, src: string, target: BuiltTexture) {
    const screenWidth_half = Math.ceil(screenWidth / 2.0);
    const screenHeight_half = Math.ceil(screenHeight / 2.0);

    let maxLod = Math.log2(Math.min(screenWidth, screenHeight));
    maxLod = Math.floor(maxLod - 2);
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    const texBloom = pipeline.createTexture('texBloom')
        .format(Format.RGB16F)
        .width(screenWidth_half)
        .height(screenHeight_half)
        .mipmap(true)
        .clear(false)
        .build();

    //const postRenderStage = pipeline.forStage(Stage.POST_RENDER);
    const bloomStage = postRenderStage.subList('Bloom');

    for (let i = 0; i < maxLod; i++) {
        bloomStage.createComposite(`bloom-down-${i}`)
            .vertex('shared/bufferless.vsh')
            .fragment('post/bloom/down.fsh')
            .target(0, texBloom, i)
            .define('TEX_SRC', i == 0 ? src : 'texBloom')
            .define('TEX_SCALE', Math.pow(2, i).toString())
            .define('BLOOM_INDEX', i.toString())
            .define('MIP_INDEX', Math.max(i-1, 0).toString())
            .compile();
    }

    for (let i = maxLod-1; i >= 0; i--) {
        new ShaderBuilder(bloomStage.createComposite(`bloom-up-${i}`)
                .vertex('shared/bufferless.vsh')
                .fragment('post/bloom/up.fsh')
                .define('TEX_SRC', src)
                .define('TEX_SCALE', Math.pow(2, i+1).toString())
                .define('BLOOM_INDEX', i.toString())
                .define('MIP_INDEX', i.toString())
            )
            .if(i == 0, builder => builder.with(s => s
                .target(0, target)
                .blendFunc(0, Func.ONE, Func.ZERO, Func.ONE, Func.ZERO)))
            .if(i != 0, builder => builder.with(s => s
                .target(0, texBloom, i-1)
                .blendFunc(0, Func.ONE, Func.ONE, Func.ONE, Func.ONE)))
            .ubo(UBO.SceneSettings, SceneSettingsBuffer)
            .compile();
    }

    bloomStage.end();
}

function defineGlobally1(name: string) {defineGlobally(name, "1");}

function cubed(x) {return x*x*x;}
