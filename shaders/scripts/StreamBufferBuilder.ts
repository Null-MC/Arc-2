import type {} from '../iris'


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
