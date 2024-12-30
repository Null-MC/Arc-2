vec2 GetAtlasCoord(const in vec2 localCoord, const in vec2 atlasMinCoord, const in vec2 atlasMaxCoord) {
    return fract(localCoord) * (atlasMaxCoord - atlasMinCoord) + atlasMinCoord;
}

vec2 GetLocalCoord(const in vec2 atlasCoord, const in vec2 atlasMinCoord, const in vec2 atlasMaxCoord) {
    return (atlasCoord - atlasMinCoord) / (atlasMaxCoord - atlasMinCoord);
}
