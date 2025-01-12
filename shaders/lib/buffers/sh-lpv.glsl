struct lpvShVoxel {  // 48
    uvec2 R;
    uvec2 G;
    uvec2 B;
};

const lpvShVoxel voxel_empty = lpvShVoxel(uvec2(0u), uvec2(0u), uvec2(0u));


layout(binding = 1) buffer shLpvBuffer {
    lpvShVoxel SH_LPV[];
};

layout(binding = 2) buffer shLpvBuffer_alt {
    lpvShVoxel SH_LPV_alt[];
};

#ifdef LPV_RSM_ENABLED
    layout(binding = 3) buffer shLpvRsmBuffer {
        lpvShVoxel SH_LPV_RSM[];
    };

    layout(binding = 4) buffer shLpvRsmBuffer_alt {
        lpvShVoxel SH_LPV_RSM_alt[];
    };
#endif

void encode_shVoxel(out lpvShVoxel voxel, const in vec4 R, const in vec4 G, const in vec4 B) {
    voxel.R.x = packHalf2x16(R.xy);
    voxel.R.y = packHalf2x16(R.zw);

    voxel.G.x = packHalf2x16(G.xy);
    voxel.G.y = packHalf2x16(G.zw);

    voxel.B.x = packHalf2x16(B.xy);
    voxel.B.y = packHalf2x16(B.zw);
}

void decode_shVoxel(const in lpvShVoxel voxel, out vec4 R, out vec4 G, out vec4 B) {
    R.xy = unpackHalf2x16(voxel.R.x);
    R.zw = unpackHalf2x16(voxel.R.y);

    G.xy = unpackHalf2x16(voxel.G.x);
    G.zw = unpackHalf2x16(voxel.G.y);

    B.xy = unpackHalf2x16(voxel.B.x);
    B.zw = unpackHalf2x16(voxel.B.y);
}
