import type {} from '../iris'


interface ShaderBuilderIf<T extends Shader<T, X>, X> {
    (shader: ShaderBuilder<T, X>): void;
}

interface ShaderBuilderWithShader<T extends Shader<T, X>, X> {
    (shader: T): void;
}

export class ShaderBuilder<T extends Shader<T, X>, X> {
    shader: T;
    ssbo_index: number = 0;
    ubo_index: number = 0;


    constructor(shader: T) {
        this.shader = shader;
    }

    ssbo(name: string, buffer: BuiltBuffer) : ShaderBuilder<T, X> {
        this.shader.define(name, this.ssbo_index.toString());
        this.shader.ssbo(this.ssbo_index, buffer);
        this.ssbo_index++;

        return this;
    }

    ubo(name: string, buffer: BuiltBuffer) : ShaderBuilder<T, X> {
        this.shader.define(name, this.ubo_index.toString());
        this.shader.ubo(this.ubo_index, buffer);
        this.ubo_index++;

        return this;
    }

    if(condition: boolean, callback: ShaderBuilderIf<T, X>) : ShaderBuilder<T, X> {
        if (condition) callback(this);
        return this;
    }

    with(callback: ShaderBuilderWithShader<T, X>) : ShaderBuilder<T, X> {
        callback(this.shader);
        return this;
    }

    define(key: string) {
        this.shader.define(key, '1');
        return this;
    }

    compile(): void {
        this.shader.compile();
    }
}
