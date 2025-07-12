void GetAtlasBounds(const in vec2 texcoord, const in vec2 midTexCoord, out vec2 atlasTileMin, out vec2 atlasTileSize) {
    vec2 coordNMid = texcoord - midTexCoord;

    atlasTileMin = min(texcoord, midTexCoord - coordNMid);
    atlasTileSize = abs(coordNMid) * 2.0;
}
