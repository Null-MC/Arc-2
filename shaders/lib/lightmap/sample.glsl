vec3 GetVanillaBlockLight(const in float lmcoord_x, const in float occlusion) {
    return blackbody(Lighting_BlockTemp) * (BLOCK_LUX * pow5(lmcoord_x)) * (occlusion*0.5 + 0.5);
}
