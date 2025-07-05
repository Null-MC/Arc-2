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
