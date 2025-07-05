import type {} from '../iris'


interface ShaderBuilderIf<T extends Shader<T>> {
    (shader: ShaderBuilder<T>): void;
}

interface ShaderBuilderWithShader<T extends Shader<T>> {
    (shader: T): void;
}

export class ShaderBuilder<T extends Shader<T>> {
    shader: T;
    programStage: ProgramStage;
    ssbo_index: number = 0;
    ubo_index: number = 0;


    constructor(shader: T) {
        this.shader = shader;
    }

    stage(programStage: ProgramStage) : ShaderBuilder<T> {
        this.programStage = programStage;
        return this;
    }

    ssbo(name: string, buffer: BuiltBuffer) : ShaderBuilder<T> {
        this.shader.define(name, this.ssbo_index.toString());
        this.shader.ssbo(this.ssbo_index, buffer);
        this.ssbo_index++;

        return this;
    }

    ubo(name: string, buffer: BuiltBuffer) : ShaderBuilder<T> {
        this.shader.define(name, this.ubo_index.toString());
        this.shader.ubo(this.ubo_index, buffer);
        this.ubo_index++;

        return this;
    }

    if(condition: boolean, callback: ShaderBuilderIf<T>) : ShaderBuilder<T> {
        if (condition) callback(this);
        return this;
    }

    with(callback: ShaderBuilderWithShader<T>) : ShaderBuilder<T> {
        callback(this.shader);
        return this;
    }

    build() {
        if (this.shader instanceof ObjectShader) {
            registerShader(this.shader.build());
        }
        else {
            registerShader(this.programStage, this.shader.build());
        }
    }
}
