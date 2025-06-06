import type {} from '../iris'


export function hexToRgb(hex: string) {
    const bigint = parseInt(hex.substring(1), 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return {r, g, b};
}

export function setLightColorEx(hex: string, ...blocks: string[]) {
    const color = hexToRgb(hex);
    blocks.forEach(block => setLightColor(new NamespacedId(block), color.r, color.g, color.b, 255));
}

export class StreamBufferBuilder {
    buffer: BuiltStreamingBuffer;
    offset: number = 0;

    constructor(buffer: BuiltStreamingBuffer) {
        this.buffer = buffer;
    }

    appendInt(value: number) {
        this.buffer.setInt(this.offset, value);
        this.offset += 4;
        return this;
    }

    appendFloat(value: number) {
        this.buffer.setFloat(this.offset, value);
        this.offset += 4;
        return this;
    }

    appendBool(value: boolean) {
        this.buffer.setBool(this.offset, value);
        this.offset += 4;
        return this;
    }
}

export class BufferFlipper {
    isAlt: boolean
    textureA: BuiltTexture;
    textureB: BuiltTexture;
    nameA: string
    nameB: string

    constructor(nameA: string, textureA: BuiltTexture, nameB: string, textureB: BuiltTexture) {
        this.nameA = nameA;
        this.textureA = textureA;
        this.nameB = nameB;
        this.textureB = textureB;
        this.isAlt = false;
    }

    flip(): void {
        this.isAlt = !this.isAlt;
    }

    getReadName(): string {
        return this.isAlt ? this.nameA : this.nameB;
    }

    getReadTexture(): BuiltTexture {
        return this.isAlt ? this.textureA : this.textureB;
    }

    getWriteTexture(): BuiltTexture {
        return this.isAlt ? this.textureB : this.textureA;
    }
}

export class TagBuilder {
    index: number = 0;

    map(name: string, namespace: NamespacedId): TagBuilder {
        if (this.index >= 32) throw new RangeError('Limit of 32 tags has been exceeded!');

        addTag(this.index, namespace);
        defineGlobally(name, this.index);
        this.index++;

        return this;
    }
}
