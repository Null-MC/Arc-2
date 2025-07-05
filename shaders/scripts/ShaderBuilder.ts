import type {} from '../iris'


export class ShaderBuilder<T extends Shader<T>> {
    shader: T;
    shaderUsage: ProgramUsage;
    ssbo_index: number = 0;


    constructor(shader: T) {
        this.shader = shader;
    }

    usage(shaderUsage: ProgramUsage) : ShaderBuilder<T> {
        this.shaderUsage = shaderUsage;
        return this;
    }

    ssbo(name: string, buffer: BuiltBuffer) : ShaderBuilder<T> {
        this.shader.define(name, this.ssbo_index.toString());
        this.shader.ssbo(this.ssbo_index, buffer);
        this.ssbo_index++;

        return this;
    }

    with(callback: CallableFunction) : ShaderBuilder<T> {
        callback(this.shader);
        return this;
    }

    build() {
        registerShader(this.usage, this.shader.build());
    }
}
