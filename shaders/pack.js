const FEATURE = {
    WaterWaves: true,
    Shadows: true,
    Bloom: true,
    GI_AO: true,
    TAA: true,
    VL: true
};

const DEBUG_HISTOGRAM = false;

const _screenWidth = 1920;
const _screenHeight = 1080;


function setupSky() {
    let texSkyTransmit = registerTexture(new Texture("texSkyTransmit")
        .format(RGB16F)
        .clear(false)
        .width(256)
        .height(64)
        .build());

    let texSkyMultiScatter = registerTexture(new Texture("texSkyMultiScatter")
        .format(RGB16F)
        .clear(false)
        .width(32)
        .height(32)
        .build());

    let texSkyView = registerTexture(new Texture("texSkyView")
        .format(RGB16F)
        .clear(false)
        .width(256)
        .height(256)
        .build());

    let texSkyIrradiance = registerTexture(new Texture("texSkyIrradiance")
        .format(RGB16F)
        .clear(false)
        .width(32)
        .height(32)
        .build());

    registerComposite(new CompositePass(SCREEN_SETUP, "sky-transmit")
        .vertex("post/bufferless.vsh")
        .fragment("setup/sky_transmit.fsh")
        .addTarget(0, texSkyTransmit)
        .build())

    registerComposite(new CompositePass(SCREEN_SETUP, "sky-multi-scatter")
        .vertex("post/bufferless.vsh")
        .fragment("setup/sky_multi_scatter.fsh")
        .addTarget(0, texSkyMultiScatter)
        .build())

    registerComposite(new CompositePass(PRE_RENDER, "sky-view")
        .vertex("post/bufferless.vsh")
        .fragment("setup/sky_view.fsh")
        .addTarget(0, texSkyView)
        .build())

    registerComposite(new CompositePass(PRE_RENDER, "sky-irradiance")
        .vertex("post/bufferless.vsh")
        .fragment("setup/sky_irradiance.fsh")
        .addTarget(0, texSkyIrradiance)
        .build())
}

function setupBloom(texFinal) {
    let maxLod = Math.log2(Math.min(_screenWidth, _screenHeight));
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    let texBloomArray = [];
    for (let i = 0; i < maxLod; i++) {
        let scale = Math.pow(2, i+1);
        let bufferWidth = Math.ceil(_screenWidth / scale);
        let bufferHeight = Math.ceil(_screenHeight / scale);

        texBloomArray[i] = registerTexture(new Texture(`texBloom_${i}`)
            .format(RGB16F)
            .width(bufferWidth)
            .height(bufferHeight)
            .clear(false)
            .build());
    }

    for (let i = 0; i < maxLod; i++) {
        let texSrc = i == 0
            ? "texFinal"
            : `texBloom_${i-1}`

        registerComposite(new CompositePass(POST_RENDER, `bloom-down-${i}`)
            .vertex("post/bufferless.vsh")
            .fragment("post/bloom/down.fsh")
            .addTarget(0, texBloomArray[i])
            .define("TEX_SRC", texSrc)
            .define("TEX_SCALE", Math.pow(2, i).toString())
            .define("BLOOM_INDEX", i.toString())
            .build());
    }

    for (let i = maxLod-1; i >= 0; i--) {
        let texOut = i == 0
            ? texFinal
            : texBloomArray[i-1];

        registerComposite(new CompositePass(POST_RENDER, `bloom-up-${i}`)
            .vertex("post/bufferless.vsh")
            .fragment("post/bloom/up.fsh")
            .define("TEX_SRC", `texBloom_${i}`)
            .define("TEX_SCALE", Math.pow(2, i+1).toString())
            .define("BLOOM_INDEX", i.toString())
            .addTarget(0, texOut)
            .blendFunc(0, FUNC_ONE, FUNC_ONE, FUNC_ONE, FUNC_ONE)
            .build());
    }
}

function setupShader() {
    print("Setting up shader");

    print(`SCREEN width: ${_screenWidth} height: ${_screenHeight}`);

    worldSettings.sunPathRotation = 25.0;
    worldSettings.shadowMapResolution = 1024;
    worldSettings.vignette = false;
    worldSettings.clouds = false;
    worldSettings.stars = false;
    worldSettings.moon = false;
    worldSettings.sun = false;

    if (FEATURE.WaterWaves) defineGlobally("WATER_WAVES_ENABLED", "1");
    if (FEATURE.Shadows) defineGlobally("SHADOWS_ENABLED", "1");
    if (FEATURE.GI_AO) defineGlobally("EFFECT_GIAO_ENABLED", "1");
    if (FEATURE.TAA) defineGlobally("EFFECT_TAA_ENABLED", "1");
    if (FEATURE.VL) defineGlobally("EFFECT_VL_ENABLED", "1");

    if (DEBUG_HISTOGRAM) defineGlobally("DEBUG_HISTOGRAM", "1");

    let texFinal = registerTexture(
        new Texture("texFinal")
        .imageName("imgFinal")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texFinalOpaque = registerTexture(
        new Texture("texFinalOpaque")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texFinalPrevious = registerTexture(
        new Texture("texFinalPrevious")
        .format(RGBA16F)
        .clear(false)
        .build());

    let texClouds = registerTexture(
        new Texture("texClouds")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texParticles = registerTexture(
        new Texture("texParticles")
        .format(RGBA16F)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texDeferredOpaque_Color = registerTexture(
        new Texture("texDeferredOpaque_Color")
        .format(RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texDeferredOpaque_Data = registerTexture(
        new Texture("texDeferredOpaque_Data")
        .format(RGB32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texDeferredTrans_Color = registerTexture(
        new Texture("texDeferredTrans_Color")
        .format(RGBA8)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texDeferredTrans_Data = registerTexture(
        new Texture("texDeferredTrans_Data")
        .format(RGB32UI)
        .clearColor(0.0, 0.0, 0.0, 0.0)
        .build());

    let texSSGIAO = null;
    let texSSGIAO_final = null;
    if (FEATURE.GI_AO) {
        texSSGIAO = registerTexture(
            new Texture("texSSGIAO")
            .format(RGBA16F)
            .width(Math.ceil(_screenWidth / 2.0))
            .height(Math.ceil(_screenHeight / 2.0))
            .clear(false)
            .build());

        texSSGIAO_final = registerTexture(
            new Texture("texSSGIAO_final")
            .imageName("imgSSGIAO_final")
            .format(RGBA16F)
            .width(Math.ceil(_screenWidth / 2.0))
            .height(Math.ceil(_screenHeight / 2.0))
            .clear(false)
            .build());
    }

    let texScatterVL = registerTexture(
        new Texture("texScatterVL")
        .format(RGB16F)
        .width(Math.ceil(_screenWidth / 2.0))
        .height(Math.ceil(_screenHeight / 2.0))
        .clear(false)
        .build());

    let texTransmitVL = registerTexture(
        new Texture("texTransmitVL")
        .format(RGB16F)
        .width(Math.ceil(_screenWidth / 2.0))
        .height(Math.ceil(_screenHeight / 2.0))
        .clear(false)
        .build());

    let texHistogram = registerTexture(
        new Texture("texHistogram")
        .imageName("imgHistogram")
        .format(R32UI)
        .width(256)
        .height(1)
        .clear(false)
        .build());

    if (DEBUG_HISTOGRAM) {
        let texHistogram_debug = registerTexture(
            new Texture("texHistogram_debug")
            .imageName("imgHistogram_debug")
            .format(R32UI)
            .width(256)
            .height(1)
            .clear(false)
            .build());
    }

    let texExposure = registerTexture(
        new Texture("texExposure")
        .imageName("imgExposure")
        .format(R16F)
        .width(1)
        .height(1)
        .clear(false)
        .build());

    // let histogramExposureBuffer = registerBuffer(
    //     new Buffer("histogramExposureBuffer", 1028)
    //     .clear(false)
    //     .build());

    // let texShadowColor = registerTexture(new Texture("texShadowColor")
    //     // .format("rgba8")
    //     // .clear([ 1.0, 1.0, 1.0, 1.0 ])
    //     .build());

    setupSky();

    if (FEATURE.Shadows) {
        registerGeometryShader(new GamePass("shadow")
            .vertex("program/shadow.vsh")
            .fragment("program/shadow.fsh")
            // .addTarget(0, texShadowColor)
            .usage(USAGE_SHADOW)
            .build());
    }

    registerGeometryShader(new GamePass("sky-color")
        .vertex("program/sky.vsh")
        .fragment("program/sky.fsh")
        .usage(USAGE_SKYBOX)
        .addTarget(0, texFinalOpaque)
        // .blendFunc(0, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .build());

    // TODO: sky-textured?

    registerGeometryShader(new GamePass("clouds")
        .usage(USAGE_CLOUDS)
        .vertex("program/main.vsh")
        .fragment("program/clouds.fsh")
        .addTarget(0, texClouds)
        .build());

    registerGeometryShader(new GamePass("terrain")
        .usage(USAGE_BASIC)
        .vertex("program/main.vsh")
        .fragment("program/main.fsh")
        .addTarget(0, texDeferredOpaque_Color)
        // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
        .addTarget(1, texDeferredOpaque_Data)
        // .blendFunc(1, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .build());

    registerGeometryShader(new GamePass("water")
        .usage(USAGE_TERRAIN_TRANSLUCENT)
        .vertex("program/main.vsh")
        .fragment("program/main.fsh")
        .define("RENDER_TRANSLUCENT", "1")
        .addTarget(0, texDeferredTrans_Color)
        // .blendFunc(0, FUNC_SRC_ALPHA, FUNC_ONE_MINUS_SRC_ALPHA, FUNC_ONE, FUNC_ZERO)
        .addTarget(1, texDeferredTrans_Data)
        // .blendFunc(1, FUNC_ONE, FUNC_ZERO, FUNC_ONE, FUNC_ZERO)
        .build());

    registerGeometryShader(new GamePass("weather")
        .usage(USAGE_WEATHER)
        .vertex("program/main.vsh")
        .fragment("program/weather.fsh")
        .addTarget(0, texParticles)
        .build());

    if (FEATURE.GI_AO) {
        registerComposite(new CompositePass(POST_RENDER, "ssgiao-opaque")
            .vertex("post/bufferless.vsh")
            .fragment("post/ssgiao.fsh")
            .addTarget(0, texSSGIAO)
            .build());

        registerComposite(new ComputePass(POST_RENDER, "ssgiao-filter-opaque")
            .barrier(true)
            .location("post/ssgiao_filter.csh")
            .groupSize(Math.ceil(_screenWidth/2.0 / 16.0), Math.ceil(screenHeight/2.0 / 16.0), 1)
            .build());

        print(`SSGIAO width: ${Math.ceil(_screenWidth/2.0 / 16.0)} height: ${Math.ceil(screenHeight/2.0 / 16.0)}`);
    }

    if (FEATURE.VL) {
        registerComposite(new CompositePass(POST_RENDER, "volumetric-far")
            .vertex("post/bufferless.vsh")
            .fragment("post/volumetric-far.fsh")
            .addTarget(0, texScatterVL)
            .addTarget(1, texTransmitVL)
            .build());
    }

    registerComposite(new CompositePass(POST_RENDER, "composite-opaque")
        .vertex("post/bufferless.vsh")
        .fragment("post/composite-opaque.fsh")
        .addTarget(0, texFinalOpaque)
        .build());

    if (FEATURE.VL) {
        registerComposite(new CompositePass(POST_RENDER, "volumetric-near")
            .vertex("post/bufferless.vsh")
            .fragment("post/volumetric-near.fsh")
            .addTarget(0, texScatterVL)
            .addTarget(1, texTransmitVL)
            .build());
    }

    registerComposite(new CompositePass(POST_RENDER, "composite-translucent")
        .vertex("post/bufferless.vsh")
        .fragment("post/composite-trans.fsh")
        .addTarget(0, texFinal)
        .build());

    if (FEATURE.TAA) {
        registerComposite(new CompositePass(POST_RENDER, "TAA")
            .vertex("post/bufferless.vsh")
            .fragment("post/taa.fsh")
            .addTarget(0, texFinal)
            .addTarget(1, texFinalPrevious)
            .build());
    }
    else {
        registerComposite(new CompositePass(POST_RENDER, "copy-prev")
            .vertex("post/bufferless.vsh")
            .fragment("post/copy.fsh")
            .define("TEX_SRC", "texFinal")
            .addTarget(0, texFinalPrevious)
            .build());
    }

    registerComposite(new ComputePass(POST_RENDER, "histogram")
        .barrier(true)
        .location("post/histogram.csh")
        .groupSize(Math.ceil(_screenWidth / 16.0), Math.ceil(screenHeight / 16.0), 1)
        // .ssbo(0, histogramExposureBuffer)
        .build());

    registerComposite(new ComputePass(POST_RENDER, "exposure")
        .barrier(true)
        .location("post/exposure.csh")
        .groupSize(1, 1, 1)
        // .ssbo(0, histogramExposureBuffer)
        .build());

    if (FEATURE.Bloom)
        setupBloom(texFinal);

    registerComposite(new CompositePass(POST_RENDER, "tonemap")
        .vertex("post/bufferless.vsh")
        .fragment("post/tonemap.fsh")
        .addTarget(0, texFinal)
        .build());

    setCombinationPass("post/final.fsh");

    useUniform("shadowLightPosition",
        "fogColor",
        "fogStart",
        "fogEnd",
        "skyColor",
        // "cloudHeight",
        "isEyeInWater",
        "cameraPos",
        "lastCameraPos",
        "screenSize",
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
        "shadowProjection",
        "shadowProjectionSize",
        "cascadeSize",
        "guiHidden");

    addUniform("gamingTime", "bool", function(state) {
        return true;
    });
}
