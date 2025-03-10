import type {} from './iris'

export function getFloatSetting(name: String): Number {
    return parseFloat(getStringSetting(name));
}

export function hexToRgb(hex: string) {
    const bigint = parseInt(hex.substring(1), 16);
    const r = (bigint >> 16) & 255;
    const g = (bigint >> 8) & 255;
    const b = bigint & 255;
    return {r, g, b};
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
