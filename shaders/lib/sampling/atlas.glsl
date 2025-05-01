#ifdef RENDER_VERTEX
    void GetAtlasBounds(const in vec2 texcoord, out vec2 atlasTileMin, out vec2 atlasTileSize, out vec2 localCoord) {
        vec2 coordMid = (gl_TextureMatrix[0] * mc_midTexCoord).xy;
        vec2 coordNMid = texcoord - coordMid;// - 0.5/atlasSize;

        atlasTileMin = min(texcoord, coordMid - coordNMid);
        atlasTileSize = abs(coordNMid) * 2.0;

        localCoord = sign(coordNMid) * 0.5 + 0.5;
    }
#endif

// atlasBounds: [0]=position [1]=size
vec2 GetAtlasCoord(const in vec2 localCoord, const in vec2 atlasTileMin, const in vec2 atlasTileSize) {
    return fract(localCoord) * atlasTileSize + atlasTileMin;
}

vec2 GetLocalCoord(const in vec2 atlasCoord, const in vec2 atlasTileMin, const in vec2 atlasTileSize) {
    return (atlasCoord - atlasTileMin) / atlasTileSize;
}
