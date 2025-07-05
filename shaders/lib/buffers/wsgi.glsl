struct lpvShVoxel {  // 48
    uvec2 data[6];
};

const lpvShVoxel voxel_empty = lpvShVoxel(uvec2[](uvec2(0u), uvec2(0u), uvec2(0u), uvec2(0u), uvec2(0u), uvec2(0u)));


layout(binding = SSBO_VXGI) buffer shLpvBuffer {
    lpvShVoxel SH_LPV[];
};

layout(binding = SSBO_VXGI_ALT) buffer shLpvBuffer_alt {
    lpvShVoxel SH_LPV_alt[];
};


const vec3 shVoxel_dir[6] = {
    vec3( 0.0, -1.0,  0.0),
    vec3( 0.0,  1.0,  0.0),
    vec3( 0.0,  0.0, -1.0),
    vec3( 0.0,  0.0,  1.0),
    vec3(-1.0,  0.0,  0.0),
    vec3( 1.0,  0.0,  0.0)
};

int get_shVoxel_dir(vec3 dir) {
    int index = 0;
    if      (dir.x >  0.5) index = 5;
    else if (dir.x < -0.5) index = 4;
    else if (dir.z >  0.5) index = 3;
    else if (dir.z < -0.5) index = 2;
    else if (dir.y >  0.5) index = 1;
    return index;
}

uvec2 encode_shVoxel_dir(const in vec3 color, const in float counter) {
    return uvec2(
        packHalf2x16(color.rg),
        packHalf2x16(vec2(color.b, counter)));
}

void decode_shVoxel_dir(const in uvec2 voxel_dir, out vec3 color, out float counter) {
    vec4 data = vec4(
        unpackHalf2x16(voxel_dir.x),
        unpackHalf2x16(voxel_dir.y));

    color.rgb = data.rgb;
    counter = data.a;
}
