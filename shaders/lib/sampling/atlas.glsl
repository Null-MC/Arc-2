// atlasBounds: [0]=position [1]=size
vec2 GetAtlasCoord(const in vec2 localCoord, const in vec2 atlasTileMin, const in vec2 atlasTileSize) {
    return fract(localCoord) * atlasTileSize + atlasTileMin;
}

vec2 GetLocalCoord(const in vec2 atlasCoord, const in vec2 atlasTileMin, const in vec2 atlasTileSize) {
    return (atlasCoord - atlasTileMin) / atlasTileSize;
}
