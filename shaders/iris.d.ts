interface InternalTextureFormat {}

declare function print(v : string)

declare var screenWidth : number
declare var screenHeight : number

declare class WorldSettings {
    shadowMapResolution : number
    shadowMapDistance : number
    shadowNearPlane : number
    shadowFarPlane : number
    sunPathRotation : number
    ambientOcclusionLevel : number
    renderSun : boolean
    renderMoon : boolean
    renderStars : boolean
    renderEntityShadow : boolean
    disableShade : boolean
}

declare var worldSettings : WorldSettings

// Formats/stages/usages

interface ProgramStage {}

declare namespace Stage {
    let PRE_RENDER : ProgramStage
    let POST_RENDER : ProgramStage
    let PRE_TRANSLUCENT : ProgramStage
    let SCREEN_SETUP : ProgramStage
}

interface ProgramUsage {}
interface BlendModeFunction {}


// Settings
declare function getStringSetting(name : string) : string
declare function getBoolSetting(name : string) : boolean
declare function setLightColor(name : string, r : number, g : number, b : number, a : number) : void
declare function setLightColor(name : string, hex : number) : void

// Uniforms

declare function registerUniforms(...uniforms : string[]) : void

declare function finalizeUniforms() : void

declare function defineGlobally(key : string, value : string)

// Shaders

interface BuiltObjectShader {}
interface BuiltCompositeShader {}

declare function registerShader(s : BuiltObjectShader) : BuiltObjectShader
declare function registerShader(stage : ProgramStage, s : BuiltCompositeShader) : BuiltCompositeShader
declare function setCombinationPass(s : BuiltCombinationPass) : BuiltCombinationPass

declare class ObjectShader {
    constructor(name : string, usage : ProgramUsage)

    vertex(loc : string) : ObjectShader
    geometry(loc : string) : ObjectShader
    control(loc : string) : ObjectShader
    eval(loc : string) : ObjectShader
    fragment(loc : string) : ObjectShader

    target(index : number, tex : BuiltTexture | undefined) : ObjectShader
    ssbo(index : number, buf : BuiltBuffer | undefined) : ObjectShader
    ubo(index : number, buf : BuiltBuffer | undefined) : ObjectShader
    define(key : string, value : string) : ObjectShader

    build() : BuiltObjectShader
}

declare class Composite {
    constructor(name : string)

    vertex(loc : string) : Composite
    geometry(loc : string) : Composite
    control(loc : string) : Composite
    eval(loc : string) : Composite
    fragment(loc : string) : Composite

    target(index : number, tex : BuiltTexture | undefined) : Composite
    generateMips(tex : BuiltTexture) : Composite
    target(index : number, tex : BuiltTexture | undefined, mip : number) : Composite
    ssbo(index : number, buf : BuiltBuffer | undefined) : Composite
    ubo(index : number, buf : BuiltBuffer | undefined) : Composite
    define(key : string, value : string) : Composite

    imageBarrier() : Composite
    ssboBarrier() : Composite
    uboBarrier() : Composite
    textureFetchBarrier() : Composite
    textureBarrier() : Composite
    blendFunc(index : number, srcRGB : BlendModeFunction, dstRGB : BlendModeFunction, srcA : BlendModeFunction, dstA : BlendModeFunction) : Composite

    build() : BuiltCompositeShader
}

declare class Compute {
    constructor(name : string)

    location(loc : string) : Compute
    workGroups(x : number, y : number, z : number) : Compute
    ssbo(index : number, buf : BuiltBuffer | undefined) : Composite
    ubo(index : number, buf : BuiltBuffer | undefined) : Composite
    define(key : string, value : string) : Composite

    imageBarrier() : Composite
    ssboBarrier() : Composite
    uboBarrier() : Composite
    textureFetchBarrier() : Composite
    textureBarrier() : Composite

    build() : BuiltCompositeShader
}

interface BuiltCombinationPass {}

declare class CombinationPass {
    constructor(location : string)
    ssbo(index : number, buf : BuiltBuffer | undefined) : ObjectShader
    ubo(index : number, buf : BuiltBuffer | undefined) : ObjectShader

    build() : BuiltCombinationPass
}

// Buffers

interface BuiltBuffer {}

declare class Buffer {
    constructor(size : number)
    clear(c : boolean) : Buffer

    build() : BuiltBuffer
}

// Textures

interface BuiltTexture {}

declare class Texture {
    constructor(name : string)

    format(internalFormat : InternalTextureFormat) : Texture
    clearColor(r : number, g : number, b : number, a : number) : Texture
    clear(clear : boolean) : Texture
    imageName(name : string) : Texture
    mipmap(mipmap : boolean) : Texture
    width(width : number) : Texture
    height(height : number) : Texture
    depth(depth : number) : Texture

    build() : BuiltTexture
}

interface PType {}

declare class RawTexture {
    constructor(name : string, location : string)

    format(internalFormat : InternalTextureFormat) : RawTexture
    type(pixel : PType) : RawTexture
    blur(b : boolean) : RawTexture
    clamp(b : boolean) : RawTexture
    clearColor(r : number, g : number, b : number, a : number) : RawTexture
    clear(clear : boolean) : RawTexture
    imageName(name : string) : RawTexture
    mipmap(mipmap : boolean) : RawTexture
    width(width : number) : RawTexture
    height(height : number) : RawTexture
    depth(depth : number) : RawTexture

    build() : BuiltTexture
}

declare class ArrayTexture {
    constructor(name : string)

    format(internalFormat : InternalTextureFormat) : ArrayTexture
    clearColor(r : number, g : number, b : number, a : number) : ArrayTexture
    clear(clear : boolean) : ArrayTexture
    imageName(name : string) : ArrayTexture
    mipmap(mipmap : boolean) : ArrayTexture
    width(width : number) : ArrayTexture
    height(height : number) : ArrayTexture

    build() : BuiltTexture

    slices(slice : number) : ArrayTexture
}

declare class PNGTexture implements BuiltTexture {
    constructor(name : string, loc : string, blur : boolean, clamp : boolean)
}

// The auto-generated stuff goes here

declare namespace PixelType {
	let BYTE : PType
	let SHORT : PType
	let INT : PType
	let HALF_FLOAT : PType
	let FLOAT : PType
	let UNSIGNED_BYTE : PType
	let UNSIGNED_BYTE_3_3_2 : PType
	let UNSIGNED_BYTE_2_3_3_REV : PType
	let UNSIGNED_SHORT : PType
	let UNSIGNED_SHORT_5_6_5 : PType
	let UNSIGNED_SHORT_5_6_5_REV : PType
	let UNSIGNED_SHORT_4_4_4_4 : PType
	let UNSIGNED_SHORT_4_4_4_4_REV : PType
	let UNSIGNED_SHORT_5_5_5_1 : PType
	let UNSIGNED_SHORT_1_5_5_5_REV : PType
	let UNSIGNED_INT : PType
	let UNSIGNED_INT_8_8_8_8 : PType
	let UNSIGNED_INT_8_8_8_8_REV : PType
	let UNSIGNED_INT_10_10_10_2 : PType
	let UNSIGNED_INT_2_10_10_10_REV : PType
	let UNSIGNED_INT_10F_11F_11F_REV : PType
	let UNSIGNED_INT_5_9_9_9_REV : PType
}

declare namespace Func {
	let ZERO : BlendModeFunction
	let ONE : BlendModeFunction
	let SRC_COLOR : BlendModeFunction
	let ONE_MINUS_SRC_COLOR : BlendModeFunction
	let DST_COLOR : BlendModeFunction
	let ONE_MINUS_DST_COLOR : BlendModeFunction
	let SRC_ALPHA : BlendModeFunction
	let ONE_MINUS_SRC_ALPHA : BlendModeFunction
	let DST_ALPHA : BlendModeFunction
	let ONE_MINUS_DST_ALPHA : BlendModeFunction
	let SRC_ALPHA_SATURATE : BlendModeFunction
}

declare namespace Format {
	let RGBA : InternalTextureFormat
	let R8 : InternalTextureFormat
	let RG8 : InternalTextureFormat
	let RGB8 : InternalTextureFormat
	let RGBA8 : InternalTextureFormat
	let R8_SNORM : InternalTextureFormat
	let RG8_SNORM : InternalTextureFormat
	let RGB8_SNORM : InternalTextureFormat
	let RGBA8_SNORM : InternalTextureFormat
	let R16 : InternalTextureFormat
	let RG16 : InternalTextureFormat
	let RGB16 : InternalTextureFormat
	let RGBA16 : InternalTextureFormat
	let R16_SNORM : InternalTextureFormat
	let RG16_SNORM : InternalTextureFormat
	let RGB16_SNORM : InternalTextureFormat
	let RGBA16_SNORM : InternalTextureFormat
	let R16F : InternalTextureFormat
	let RG16F : InternalTextureFormat
	let RGB16F : InternalTextureFormat
	let RGBA16F : InternalTextureFormat
	let R32F : InternalTextureFormat
	let RG32F : InternalTextureFormat
	let RGB32F : InternalTextureFormat
	let RGBA32F : InternalTextureFormat
	let R8I : InternalTextureFormat
	let RG8I : InternalTextureFormat
	let RGB8I : InternalTextureFormat
	let RGBA8I : InternalTextureFormat
	let R8UI : InternalTextureFormat
	let RG8UI : InternalTextureFormat
	let RGB8UI : InternalTextureFormat
	let RGBA8UI : InternalTextureFormat
	let R16I : InternalTextureFormat
	let RG16I : InternalTextureFormat
	let RGB16I : InternalTextureFormat
	let RGBA16I : InternalTextureFormat
	let R16UI : InternalTextureFormat
	let RG16UI : InternalTextureFormat
	let RGB16UI : InternalTextureFormat
	let RGBA16UI : InternalTextureFormat
	let R32I : InternalTextureFormat
	let RG32I : InternalTextureFormat
	let RGB32I : InternalTextureFormat
	let RGBA32I : InternalTextureFormat
	let R32UI : InternalTextureFormat
	let RG32UI : InternalTextureFormat
	let RGB32UI : InternalTextureFormat
	let RGBA32UI : InternalTextureFormat
	let RGBA2 : InternalTextureFormat
	let RGBA4 : InternalTextureFormat
	let R3_G3_B2 : InternalTextureFormat
	let RGB5_A1 : InternalTextureFormat
	let RGB565 : InternalTextureFormat
	let RGB10_A2 : InternalTextureFormat
	let RGB10_A2UI : InternalTextureFormat
	let R11F_G11F_B10F : InternalTextureFormat
	let RGB9_E5 : InternalTextureFormat
}

declare namespace Usage {
    let BASIC : ProgramUsage
    let TEXTURED : ProgramUsage
    let EMISSIVE : ProgramUsage
    let CLOUDS : ProgramUsage
    let SKYBOX : ProgramUsage
    let SKY_TEXTURES : ProgramUsage
    let TERRAIN_SOLID : ProgramUsage
    let TERRAIN_CUTOUT : ProgramUsage
    let TERRAIN_TRANSLUCENT : ProgramUsage
    let TEXT : ProgramUsage
    let ENTITY_SOLID : ProgramUsage
    let ENTITY_CUTOUT : ProgramUsage
    let ENTITY_TRANSLUCENT : ProgramUsage
    let LIGHTNING : ProgramUsage
    let ENTITY_GLINT : ProgramUsage
    let BLOCK_ENTITY : ProgramUsage
    let BLOCK_ENTITY_TRANSLUCENT : ProgramUsage
    let PARTICLES : ProgramUsage
    let PARTICLES_TRANSLUCENT : ProgramUsage
    let CRUMBLING : ProgramUsage
    let LINES : ProgramUsage
    let WEATHER : ProgramUsage
    let HAND : ProgramUsage
    let TRANSLUCENT_HAND : ProgramUsage
    let SHADOW : ProgramUsage
    let SHADOW_TEXTURED : ProgramUsage
    let SHADOW_TERRAIN_SOLID : ProgramUsage
    let SHADOW_TERRAIN_CUTOUT : ProgramUsage
    let SHADOW_TERRAIN_TRANSLUCENT : ProgramUsage
    let SHADOW_ENTITY_SOLID : ProgramUsage
    let SHADOW_ENTITY_CUTOUT : ProgramUsage
    let SHADOW_ENTITY_TRANSLUCENT : ProgramUsage
    let SHADOW_BLOCK_ENTITY : ProgramUsage
    let SHADOW_BLOCK_ENTITY_TRANSLUCENT : ProgramUsage
    let SHADOW_PARTICLES : ProgramUsage
    let SHADOW_PARTICLES_TRANSLUCENT : ProgramUsage
}