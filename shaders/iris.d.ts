/**
 * Prints text to the game log.
 * @param v The text to print
 */
declare function print(v: any);

/**
 * The screen width. This is generally a constant, since setupShader will run on screen resize.
 */
declare var screenWidth: number;

/**
 * The screen height. This is generally a constant, since setupShader will run on screen resize.
 */
declare var screenHeight: number;

/**
 * The world settings. These control fixed rendering parameters of the pipeline.
 */
declare class WorldSettings {
    /**
     * Default: 1024
     */
  shadowMapResolution: number;
  cascadeCount: number;
  cascadeSafeZones: number[];
  shadowMapDistance: number;
  shadowNearPlane: number;
  shadowFarPlane: number;
  sunPathRotation: number;
  ambientOcclusionLevel: number;
  renderSun: boolean;
  renderMoon: boolean;
  renderStars: boolean;
  renderEntityShadow: boolean;
  disableShade: boolean;
}

/**
 * For details, read {@link WorldSettings}.
 */
declare var worldSettings: WorldSettings;

// Formats/stages/usages

/**
 * @see Stage
 */
interface ProgramStage {}

declare class NamespacedId {
    /**
     * Creates a new NamespacedId from a combined string. If the string is in the format `namespace:path`, the NamespacedId will be created accordingly, otherwise it will use the `minecraft` namespace.
     * @param combined The combined `namespace:path`, or `path` if `minecraft` is the desired namespace
     */
    constructor(combined : string);

    /**
     * Creates a new NamespacedId from a separate namespace and path.
     */
    constructor(namespace : string, path : string);

    getNamespace() : string;
    getPath() : string;
}

/**
 * The possible program stages for post passes.
 */
declare namespace Stage {
    /**
    * Runs before any rendering takes place.
    */
  let PRE_RENDER: ProgramStage;

    /**
    * Runs after the shadow pass is drawn.
    */
  let POST_SHADOW: ProgramStage;

    /**
     * Runs after all main rendering takes place.
     */
  let POST_RENDER: ProgramStage;

    /**
     * Runs after opaque terrain is rendered, but before translucent terrain and entities.
     */
  let PRE_TRANSLUCENT: ProgramStage;

    /**
     * Runs only once; when the shader is set up (or the screen is resized).
     */
  let SCREEN_SETUP: ProgramStage;
}

declare function writeMatrixToAddress(buffer : BuiltStreamingBuffer, offset : number, matrix : Matrix4f);

/**
 * @see Usage
 */
interface ProgramUsage {}

/**
 * @see Func
 */
interface BlendModeFunction {}

// Settings
declare function getStringSetting(name: string): string;
declare function getBoolSetting(name: string): boolean;
declare function getIntSetting(name: string): number;
declare function getFloatSetting(name: string): number;

declare class IntSetting {
  needsReload(reload: boolean): IntSetting;
  build(defaultValue: number): BuiltSetting;
}
declare class FloatSetting {
  needsReload(reload: boolean): FloatSetting;
  build(defaultValue: number): BuiltSetting;
}
declare class StringSetting {
  needsReload(reload: boolean): StringSetting;
  build(defaultValue: string): BuiltSetting;
}
declare class BuiltSetting {}

declare class Page {
  constructor(name: string);

  add(...settings): Page;
  build(): BuiltPage;
}
declare class BuiltPage {}

declare function asInt(name: string, ...values: number[]): IntSetting;
declare function asFloat(name: string, ...values: number[]): FloatSetting;
declare function putTextLabel(id : string, text : string) : BuiltSetting
declare function putTranslationLabel(id : string, text : string) : BuiltSetting
declare function asString(name: string, ...values: string[]): StringSetting;
declare function asBool(name: string, defaultValue: boolean, reload: boolean): BuiltSetting;

declare var EMPTY: BuiltPage;


/**
 * Sets the light color for the provided block.
 * @param name The colon-separated name of the block (ex. "minecraft:stone")
 * @param r the red value (0-255)
 * @param g the green value (0-255)
 * @param b the blue value (0-255)
 * @param a the alpha value (0-255)
 * @alpha
 */
declare function setLightColor(
  name: NamespacedId,
  r: number,
  g: number,
  b: number,
  a: number,
): void;

/**
 * Sets the light color for the provided block. The hex function is currently unstable.
 * @param name The colon-separated name of the block (ex. "minecraft:stone")
 * @param hex The hex color to set
 * @alpha
 */
declare function setLightColor(name: NamespacedId, hex: number): void;

// Uniforms

declare function addTag(index : number, tag : NamespacedId) : void;

declare function createTag(tag : NamespacedId, ...blocks : NamespacedId[]) : NamespacedId;

/**
 * Registers a define for all future shaders. Behavior for shaders already made is undefined.
 * @param key The key to register
 * @param value The value to register
 */
declare function defineGlobally(key: string, value: string | number): void;

// Shaders

interface BuiltObjectShader {}
interface PostPass {}

/**
 * Registers an object shader.
 * @param s The object shader
 */
declare function registerShader(s: BuiltObjectShader): BuiltObjectShader;

/**
 * Registers a post pass/composite shader. This is ordered.
 * @param stage The stage to register in
 * @param s The shader to register
 */
declare function registerShader(stage: ProgramStage, s: PostPass): PostPass;

/**
 * Sets the combination pass. This is required.
 * @param s Combination pass to set
 */
declare function setCombinationPass(
  s: BuiltCombinationPass,
): BuiltCombinationPass;

/**
 * For {@link MemoryBarrier}. Indicates all SSBO operations must be visible in the next pass.
 */
declare var SSBO_BIT: number;

/**
 * For {@link MemoryBarrier}. Indicates all UBO operations must be visible in the next pass.
 */
declare var UBO_BIT: number;

/**
 * For {@link MemoryBarrier}. Indicates all imageStore operations must be visible in the next pass.
 */
declare var IMAGE_BIT: number;

/**
 * For {@link MemoryBarrier}. Indicates all texture fetch operations must reflect data set in past passes.
 */
declare var FETCH_BIT: number;

interface Barrier {}

/**
 * Registers either a {@link TextureBarrier} or {@link MemoryBarrier}.
 * @param stage The program stage to register
 * @param b The barrier to register
 */
declare function registerBarrier(stage: ProgramStage, b: Barrier): Barrier;

/**
 * A built-in pass to copy textures. Register with {@link registerShader}.
 */
declare class TextureCopy {
  constructor(src: BuiltTexture, dst: BuiltTexture);

  /**
   * Required. Sets the size of the texture copy.
   * @param width The width of the texture copy
   * @param height The height of the texture copy
   */
  size(width: number, height: number): TextureCopy;

  /**
   * Optional operation. Offsets the source texture copy position.
   * @param x The X coordinate to start copying from
   * @param y The Y coordinate to start copying from
   */
  srcPos(x: number, y: number): TextureCopy;

  /**
   * Optional operation. Offsets the destination texture copy position.
   * @param x The X coordinate to copy to
   * @param y The Y coordinate to copy to
   */
  dstPos(x: number, y: number): TextureCopy;

  /**
   * Builds the texture copy pass.
   */
  build(): PostPass;
}

/**
 * A memory barrier, to be registered with {@link registerBarrier}.
 */
declare class MemoryBarrier implements Barrier {
  /**
   * The barriers to run.
   * @param flags A bitmask of {@link SSBO_BIT}, {@link UBO_BIT}, {@link IMAGE_BIT}, and {@link FETCH_BIT} depending on usage.
   */
  constructor(flags: number);
}

/**
 * A texture barrier. This is <b>not</b> a memory barrier, and is only useful for specific conditions.
 */
declare class TextureBarrier implements Barrier {
  constructor();
}

declare class ObjectShader {
  constructor(name: string, usage: ProgramUsage);

  vertex(loc: string): ObjectShader;
  geometry(loc: string): ObjectShader;
  control(loc: string): ObjectShader;
  eval(loc: string): ObjectShader;
  fragment(loc: string): ObjectShader;

  blendFunc(
        index: number,
        srcRGB: BlendModeFunction,
        dstRGB: BlendModeFunction,
        srcA: BlendModeFunction,
        dstA: BlendModeFunction,
    ): ObjectShader;

  blendOff(index : number) : ObjectShader;

  target(index: number, tex: BuiltTexture | undefined): ObjectShader;
  ssbo(index: number, buf: BuiltBuffer | undefined): ObjectShader;
  ubo(index: number, buf: BuiltBuffer | undefined): ObjectShader;
  define(key: string, value: string): ObjectShader;

  build(): BuiltObjectShader;
}

declare class Composite {
  constructor(name: string);

  vertex(loc: string): Composite;
  geometry(loc: string): Composite;
  control(loc: string): Composite;
  eval(loc: string): Composite;
  fragment(loc: string): Composite;

  target(index: number, tex: BuiltTexture | undefined): Composite;
  generateMips(tex: BuiltTexture): Composite;
  target(index: number, tex: BuiltTexture | undefined, mip: number): Composite;
  ssbo(index: number, buf: BuiltBuffer | undefined): Composite;
  ubo(index: number, buf: BuiltBuffer | undefined): Composite;
  define(key: string, value: string): Composite;

  blendFunc(
    index: number,
    srcRGB: BlendModeFunction,
    dstRGB: BlendModeFunction,
    srcA: BlendModeFunction,
    dstA: BlendModeFunction,
  ): Composite;

  build(): PostPass;
}

declare class Compute {
  constructor(name: string);

  location(loc: string): Compute;
  workGroups(x: number, y: number, z: number): Compute;
  ssbo(index: number, buf: BuiltBuffer | undefined): Composite;
  ubo(index: number, buf: BuiltBuffer | undefined): Composite;
  define(key: string, value: string): Composite;

  build(): PostPass;
}

/**
 * The result of making a {@link CombinationPass}.
 */
interface BuiltCombinationPass {}

declare class CombinationPass {
  constructor(location: string);
  ssbo(index: number, buf: BuiltBuffer | undefined): ObjectShader;
  ubo(index: number, buf: BuiltBuffer | undefined): ObjectShader;

  build(): BuiltCombinationPass;
}

// Buffers

/**
 * The result of a {@link Buffer}.
 */
interface BuiltGPUBuffer extends BuiltBuffer {}

/**
 * The result of a {@link Buffer}.
 */
interface BuiltBuffer {}

/**
 * The result of a {@link StreamingBuffer}.
 */
class BuiltStreamingBuffer implements BuiltBuffer {
    setInt(offset : number, value: number): void;
    setFloat(offset : number, value: number): void;
    setBool(offset : number, value: boolean): void;
    uploadData() : void;
}

/**
 * A GPU buffer, to be bound as either an SSBO or UBO. Cannot be modified at all on the CPU.
 */
declare class GPUBuffer {
  constructor(size: number);
  clear(c: boolean): GPUBuffer;

  build(): BuiltBuffer;
}

declare class Vector2f {
    /**
     * Initializes to 0.
     */
    constructor();
    constructor(x : number, y: number);
    constructor(other : Vector2f);

    x() : number;
    y() : number;

    x(newValue : number) : void;
    y(newValue : number) : void;
}

declare class Vector3f {
    /**
     * Initializes to 0.
     */
    constructor();

    constructor(x : number, y: number, z: number);
    constructor(other : Vector3f);

    x() : number;
    y() : number;
    z() : number;

    x(newValue : number) : void;
    y(newValue : number) : void;
    z(newValue : number) : void;
}

declare class Vector4f {
    /**
     * Initializes to (0, 0, 0, 1).
     */
    constructor();

    constructor(x : number, y: number, z: number, w : number);
    constructor(other : Vector4f);

    x() : number;
    y() : number;
    z() : number;
    w() : number;

    x(newValue : number) : void;
    y(newValue : number) : void;
    z(newValue : number) : void;
    w(newValue : number) : void;
}

declare class Matrix4f {
    /**
     * Initializes to identity.
     */
    constructor();

    /**
     * Makes a copy of {@link matrix}.
     * @param matrix The matrix to copy
     * @return a new copy
     */
    constructor(matrix : Matrix4f);

    m00() : number;
    m01() : number;
    m02() : number;
    m03() : number;
    m10() : number;
    m11() : number;
    m12() : number;
    m13() : number;
    m20() : number;
    m21() : number;
    m22() : number;
    m23() : number;
    m30() : number;
    m31() : number;
    m32() : number;
    m33() : number;

    m00(newValue : number) : void;
    m01(newValue : number) : void;
    m02(newValue : number) : void;
    m03(newValue : number) : void;
    m10(newValue : number) : void;
    m11(newValue : number) : void;
    m12(newValue : number) : void;
    m13(newValue : number) : void;
    m20(newValue : number) : void;
    m21(newValue : number) : void;
    m22(newValue : number) : void;
    m23(newValue : number) : void;
    m30(newValue : number) : void;
    m31(newValue : number) : void;
    m32(newValue : number) : void;
    m33(newValue : number) : void;

    /**
     * This transforms the matrix with another one, and stores the result in {@link saveMatrix}.
     * @param otherMatrix The other matrix
     * @param saveMatrix The matrix that will store the result
     * @returns saveMatrix
     */
    mul(otherMatrix : Matrix4f, saveMatrix : Matrix4f) : Matrix4f;

    /**
     * This transforms the matrix with a {@link Vector4f}, and stores the result in {@link saveVector}.
     * @param vector The vector to transform
     * @param saveVector The vector that will store the result
     * @returns saveVector
     */
    transform(vector : Vector4f, saveVector : Vector4f) : Vector4f;

    /**
     * This transforms the matrix with a {@link Vector3f}, and stores the result in {@link saveVector}.
     * @param vector The vector to transform
     * @param saveVector The vector that will store the result
     * @returns saveVector
     */
    transformPosition(vector : Vector3f, saveVector : Vector3f) : Vector3f;

    translate(x : number, y : number, z : number) : Matrix4f;
    scale(x : number, y : number, z : number) : Matrix4f;
    rotate(angle : number, x : number, y : number, z : number) : Matrix4f;
}

declare class WorldState {
    /**
     * Returns the projection matrix. This will always be a new copy.
     */
    projection() : Matrix4f;

    /**
     * Returns the view matrix. This will always be a new copy.
     */
    view() : Matrix4f;

    /**
     * Returns the camera position. This will always be a new copy.
     */
    cameraPos() : Vector3f;

    /**
     * Return the last frame time (ap.time.delta).
     */
    lastFrameTime() : number;

    /**
     * Return the elapsed frame time (ap.time.elapsed).
     */
    frameTimeCounter() : number;

    /**
     * Return the current frame (ap.time.frames).
     */
    currentFrame() : number;
}

/**
 * A buffer with data streamed every frame from the CPU.
 * Automatically cleared
 */
declare class StreamingBuffer {
  constructor(size: number);

  build(): BuiltStreamingBuffer;
}

// Textures

/**
 * @see Format
 */
interface InternalTextureFormat {}

/**
 * A built texture. This is the result of making an {@link Texture} or {@link ArrayTexture}.
 * This is also automatically implemented by {@link PNGTexture} and {@link RawTexture}.
 */
interface BuiltTexture {
    readBack() : ArrayBuffer;
}

/**
 * A basic, non-array read/write texture.
 * @see ArrayTexture
 */
declare class Texture {
  constructor(name: string);

  format(internalFormat: InternalTextureFormat): Texture;
  clearColor(r: number, g: number, b: number, a: number): Texture;
  clear(clear: boolean): Texture;
  imageName(name: string): Texture;
  mipmap(mipmap: boolean): Texture;
  width(width: number): Texture;
  height(height: number): Texture;
  depth(depth: number): Texture;
  readBack(read: boolean): Texture;

  build(): BuiltTexture;
}

/**
 * @see PixelType
 */
interface PType {}

/**
 * A texture with <b>raw</b> data loaded from the shader pack folder. Read-only.
 * @see PNGTexture
 */
declare class RawTexture {
  constructor(name: string, location: string);

  format(internalFormat: InternalTextureFormat): RawTexture;
  type(pixel: PType): RawTexture;
  blur(b: boolean): RawTexture;
  clamp(b: boolean): RawTexture;
  clearColor(r: number, g: number, b: number, a: number): RawTexture;
  clear(clear: boolean): RawTexture;
  imageName(name: string): RawTexture;
  mipmap(mipmap: boolean): RawTexture;
  width(width: number): RawTexture;
  height(height: number): RawTexture;
  depth(depth: number): RawTexture;

  build(): BuiltTexture;
}

/**
 * An array read/write texture. This is most useful for the shadow pass, which takes array textures as targets.
 * @see Texture
 */
declare class ArrayTexture {
  constructor(name: string);

  format(internalFormat: InternalTextureFormat): ArrayTexture;
  clearColor(r: number, g: number, b: number, a: number): ArrayTexture;
  clear(clear: boolean): ArrayTexture;
  imageName(name: string): ArrayTexture;
  mipmap(mipmap: boolean): ArrayTexture;
  width(width: number): ArrayTexture;
  height(height: number): ArrayTexture;

  build(): BuiltTexture;

  slices(slice: number): ArrayTexture;
}

/**
 * A texture with a PNG file loaded from the shader pack folder. Read-only.
 * @see RawTexture
 */
declare class PNGTexture implements BuiltTexture {
  constructor(name: string, loc: string, blur: boolean, clamp: boolean);
}

// The auto-generated stuff goes here

declare namespace PixelType {
  let BYTE: PType;
  let SHORT: PType;
  let INT: PType;
  let HALF_FLOAT: PType;
  let FLOAT: PType;
  let UNSIGNED_BYTE: PType;
  let UNSIGNED_BYTE_3_3_2: PType;
  let UNSIGNED_BYTE_2_3_3_REV: PType;
  let UNSIGNED_SHORT: PType;
  let UNSIGNED_SHORT_5_6_5: PType;
  let UNSIGNED_SHORT_5_6_5_REV: PType;
  let UNSIGNED_SHORT_4_4_4_4: PType;
  let UNSIGNED_SHORT_4_4_4_4_REV: PType;
  let UNSIGNED_SHORT_5_5_5_1: PType;
  let UNSIGNED_SHORT_1_5_5_5_REV: PType;
  let UNSIGNED_INT: PType;
  let UNSIGNED_INT_8_8_8_8: PType;
  let UNSIGNED_INT_8_8_8_8_REV: PType;
  let UNSIGNED_INT_10_10_10_2: PType;
  let UNSIGNED_INT_2_10_10_10_REV: PType;
  let UNSIGNED_INT_10F_11F_11F_REV: PType;
  let UNSIGNED_INT_5_9_9_9_REV: PType;
}

declare namespace Func {
  let ZERO: BlendModeFunction;
  let ONE: BlendModeFunction;
  let SRC_COLOR: BlendModeFunction;
  let ONE_MINUS_SRC_COLOR: BlendModeFunction;
  let DST_COLOR: BlendModeFunction;
  let ONE_MINUS_DST_COLOR: BlendModeFunction;
  let SRC_ALPHA: BlendModeFunction;
  let ONE_MINUS_SRC_ALPHA: BlendModeFunction;
  let DST_ALPHA: BlendModeFunction;
  let ONE_MINUS_DST_ALPHA: BlendModeFunction;
  let SRC_ALPHA_SATURATE: BlendModeFunction;
}

declare namespace Format {
  let RGBA: InternalTextureFormat;
  let R8: InternalTextureFormat;
  let RG8: InternalTextureFormat;
  let RGB8: InternalTextureFormat;
  let RGBA8: InternalTextureFormat;
  let R8_SNORM: InternalTextureFormat;
  let RG8_SNORM: InternalTextureFormat;
  let RGB8_SNORM: InternalTextureFormat;
  let RGBA8_SNORM: InternalTextureFormat;
  let R16: InternalTextureFormat;
  let RG16: InternalTextureFormat;
  let RGB16: InternalTextureFormat;
  let RGBA16: InternalTextureFormat;
  let R16_SNORM: InternalTextureFormat;
  let RG16_SNORM: InternalTextureFormat;
  let RGB16_SNORM: InternalTextureFormat;
  let RGBA16_SNORM: InternalTextureFormat;
  let R16F: InternalTextureFormat;
  let RG16F: InternalTextureFormat;
  let RGB16F: InternalTextureFormat;
  let RGBA16F: InternalTextureFormat;
  let R32F: InternalTextureFormat;
  let RG32F: InternalTextureFormat;
  let RGB32F: InternalTextureFormat;
  let RGBA32F: InternalTextureFormat;
  let R8I: InternalTextureFormat;
  let RG8I: InternalTextureFormat;
  let RGB8I: InternalTextureFormat;
  let RGBA8I: InternalTextureFormat;
  let R8UI: InternalTextureFormat;
  let RG8UI: InternalTextureFormat;
  let RGB8UI: InternalTextureFormat;
  let RGBA8UI: InternalTextureFormat;
  let R16I: InternalTextureFormat;
  let RG16I: InternalTextureFormat;
  let RGB16I: InternalTextureFormat;
  let RGBA16I: InternalTextureFormat;
  let R16UI: InternalTextureFormat;
  let RG16UI: InternalTextureFormat;
  let RGB16UI: InternalTextureFormat;
  let RGBA16UI: InternalTextureFormat;
  let R32I: InternalTextureFormat;
  let RG32I: InternalTextureFormat;
  let RGB32I: InternalTextureFormat;
  let RGBA32I: InternalTextureFormat;
  let R32UI: InternalTextureFormat;
  let RG32UI: InternalTextureFormat;
  let RGB32UI: InternalTextureFormat;
  let RGBA32UI: InternalTextureFormat;
  let RGBA2: InternalTextureFormat;
  let RGBA4: InternalTextureFormat;
  let R3_G3_B2: InternalTextureFormat;
  let RGB5_A1: InternalTextureFormat;
  let RGB565: InternalTextureFormat;
  let RGB10_A2: InternalTextureFormat;
  let RGB10_A2UI: InternalTextureFormat;
  let R11F_G11F_B10F: InternalTextureFormat;
  let RGB9_E5: InternalTextureFormat;
}

declare namespace Usage {
  let BASIC: ProgramUsage;
  let TEXTURED: ProgramUsage;
  let EMISSIVE: ProgramUsage;
  let CLOUDS: ProgramUsage;
  let SKYBOX: ProgramUsage;
  let SKY_TEXTURES: ProgramUsage;
  let TERRAIN_SOLID: ProgramUsage;
  let TERRAIN_CUTOUT: ProgramUsage;
  let TERRAIN_TRANSLUCENT: ProgramUsage;
  let TEXT: ProgramUsage;
  let ENTITY_SOLID: ProgramUsage;
  let ENTITY_CUTOUT: ProgramUsage;
  let ENTITY_TRANSLUCENT: ProgramUsage;
  let LIGHTNING: ProgramUsage;
  let ENTITY_GLINT: ProgramUsage;
  let BLOCK_ENTITY: ProgramUsage;
  let BLOCK_ENTITY_TRANSLUCENT: ProgramUsage;
  let PARTICLES: ProgramUsage;
  let PARTICLES_TRANSLUCENT: ProgramUsage;
  let CRUMBLING: ProgramUsage;
  let LINES: ProgramUsage;
  let WEATHER: ProgramUsage;
  let HAND: ProgramUsage;
  let TRANSLUCENT_HAND: ProgramUsage;
  let SHADOW: ProgramUsage;
  let SHADOW_TEXTURED: ProgramUsage;
  let SHADOW_TERRAIN_SOLID: ProgramUsage;
  let SHADOW_TERRAIN_CUTOUT: ProgramUsage;
  let SHADOW_TERRAIN_TRANSLUCENT: ProgramUsage;
  let SHADOW_ENTITY_SOLID: ProgramUsage;
  let SHADOW_ENTITY_CUTOUT: ProgramUsage;
  let SHADOW_ENTITY_TRANSLUCENT: ProgramUsage;
  let SHADOW_BLOCK_ENTITY: ProgramUsage;
  let SHADOW_BLOCK_ENTITY_TRANSLUCENT: ProgramUsage;
  let SHADOW_PARTICLES: ProgramUsage;
  let SHADOW_PARTICLES_TRANSLUCENT: ProgramUsage;
}
