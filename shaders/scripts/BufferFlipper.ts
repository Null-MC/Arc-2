import type {} from '../iris'


export class BufferFlipper {
    isAlt: boolean
    textureA: BuiltTexture;
    textureB: BuiltTexture;

    constructor(nameA: string, textureA: BuiltTexture, nameB: string, textureB: BuiltTexture) {
        this.textureA = textureA;
        this.textureB = textureB;
        this.isAlt = false;
    }

    flip(): void {
        this.isAlt = !this.isAlt;
    }

    getReadName(): string {
        return this.isAlt ? this.textureA.name() : this.textureB.name();
    }

    getReadTexture(): BuiltTexture {
        return this.isAlt ? this.textureA : this.textureB;
    }

    getWriteTexture(): BuiltTexture {
        return this.isAlt ? this.textureB : this.textureA;
    }
}
