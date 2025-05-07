//import type {} from '../iris'

export class BlockMeta
{
    block: string
    define: string
    index: number
}

export class BlockMap
{
    mappings: Record<string, BlockMeta> = {};
    index: number = 0;

    map(block: string, define: string) : BlockMap {
        const meta = new BlockMeta();
        meta.index = ++this.index;
        meta.block = block;
        meta.define = define;
        this.mappings[block] = meta;
        return this;
    }

    get(block: string) : BlockMeta | undefined {
        return this.mappings[block];
    }
}
