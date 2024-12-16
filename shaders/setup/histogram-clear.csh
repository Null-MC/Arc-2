#version 430 core

layout (local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(r32ui) uniform writeonly uimage2D imgHistogram;


void main() {
    ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
    imageStore(imgHistogram, uv, uvec4(0u));
}
