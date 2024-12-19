struct lpvShVoxel {  // 48
    f16vec4 R;
    f16vec4 G;
    f16vec4 B;
};

const lpvShVoxel voxel_empty = lpvShVoxel(f16vec4(0.0), f16vec4(0.0), f16vec4(0.0));


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
