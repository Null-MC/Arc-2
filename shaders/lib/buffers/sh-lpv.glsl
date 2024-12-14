struct lpvShVoxel {  // 48
    vec4 R;
    vec4 G;
    vec4 B;
};

const lpvShVoxel voxel_empty = lpvShVoxel(vec4(0.0), vec4(0.0), vec4(0.0));


layout(binding = 1) buffer shLpvBuffer {
    lpvShVoxel SH_LPV[];
};

layout(binding = 2) buffer shLpvBuffer_alt {
    lpvShVoxel SH_LPV_alt[];
};
