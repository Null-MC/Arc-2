const ENABLE_Bloom = true;
const ENABLE_TAA = false;
const ENABLE_VL = true;


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

    registerComposite(new CompositePass(PRE_RENDER, "sky-transmit")
        .vertex("post/bufferless.vsh")
        .fragment("setup/sky_transmit.fsh")
        .addTarget(0, texSkyTransmit)
        .build())

    registerComposite(new CompositePass(PRE_RENDER, "sky-multi-scatter")
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
    // WARN: temporarily hard-coded
    const viewWidth = 1920;
    const viewHeight = 1080;

    let maxLod = Math.log2(Math.min(viewWidth, viewHeight));
    maxLod = Math.max(Math.min(maxLod, 8), 0);

    print(`Bloom enabled with ${maxLod} LODs`);

    let texBloomArray = [];
    for (let i = 0; i < maxLod; i++) {
        let scale = Math.pow(2, i+1);
        let bufferWidth = Math.ceil(viewWidth / scale);
        let bufferHeight = Math.ceil(viewHeight / scale);

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

        let texDown = i == 0
            ? "texFinal"
            : `texBloom_${i-1}`

        registerComposite(new CompositePass(POST_RENDER, `bloom-up-${i}`)
            .vertex("post/bufferless.vsh")
            .fragment("post/bloom/up.fsh")
            .define("TEX_DOWN", texDown)
            .define("TEX_SRC", `texBloom_${i}`)
            .define("TEX_SCALE", Math.pow(2, i+1).toString())
            .define("BLOOM_INDEX", i.toString())
            .addTarget(0, texOut)
            .build());
    }
}

function setupShader() {
    print("Setting up shader");

    worldSettings.sunPathRotation = 25.0;
    worldSettings.shadowMapResolution = 1024;
    worldSettings.vignette = false;
    worldSettings.stars = false;
    worldSettings.moon = true;
    worldSettings.sun = false;

    let texFinal = registerTexture(new Texture("texFinal")
        .format(RGBA16F)
        .clear(true)
        .build());

    // let texShadowColor = registerTexture(new Texture("texShadowColor")
    //     // .format("rgba8")
    //     // .clear([ 1.0, 1.0, 1.0, 1.0 ])
    //     .build());

    setupSky();

    registerGeometryShader(new GamePass("sky-color")
        .vertex("program/sky.vsh")
        .fragment("program/sky.fsh")
        .usage(USAGE_SKYBOX)
        .addTarget(0, texFinal)
        .build());

    // TODO: sky-textured?

    registerGeometryShader(new GamePass("terrain")
        .usage(USAGE_BASIC)
        .vertex("program/main.vsh")
        .fragment("program/main.fsh")
        .addTarget(0, texFinal)
        .build());

    registerGeometryShader(new GamePass("water")
        .usage(USAGE_TERRAIN_TRANSLUCENT)
        .vertex("program/main.vsh")
        .fragment("program/translucent.fsh")
        .addTarget(0, texFinal)
        .build());

    registerGeometryShader(new GamePass("shadow")
        .vertex("program/shadow.vsh")
        .fragment("program/shadow.fsh")
        // .addTarget(0, texShadowColor)
        .usage(USAGE_SHADOW)
        .build());

    if (ENABLE_VL) {
        registerComposite(new CompositePass(POST_RENDER, "volumetric")
            .vertex("post/bufferless.vsh")
            .fragment("post/volumetric.fsh")
            .addTarget(0, texFinal)
            .build());
    }

    if (ENABLE_Bloom)
        setupBloom(texFinal);

    registerComposite(new CompositePass(POST_RENDER, "tonemap")
        .vertex("post/bufferless.vsh")
        .fragment("post/tonemap.fsh")
        .addTarget(0, texFinal)
        .build());

    if (ENABLE_TAA) {
        registerComposite(new CompositePass(POST_RENDER, "TAA")
            .vertex("post/bufferless.vsh")
            .fragment("post/taa.fsh")
            .addTarget(0, texFinal)
            .build());
    }

    setCombinationPass("post/final.fsh")

    useUniform("shadowLightPosition",
        "fogColor",
        "skyColor",
        "fogStart",
        "cameraPos",
        "fogEnd",
        "screenSize",
        "frameCounter",
        "worldTime",
        "dayProgression",
        "timeCounter",
        "rainStrength",
        "nearPlane",
        "renderDistance",
        "playerModelView",
        "playerModelViewInverse",
        "playerProjection",
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
