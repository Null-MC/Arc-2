const ivec3 WSGI_BufferSize = ivec3(LIGHTING_GI_SIZE);
const ivec3 WSGI_BufferCenter = WSGI_BufferSize / 2;


float wsgi_getVoxelSize(const in int voxelScale) {
    return exp2(voxelScale) * 0.5;
}

vec3 wsgi_getStepInterval(const in vec3 cameraPos) {
    const vec3 scale = vec3(WSGI_SNAP_SCALE);
    return fract(cameraPos / scale) * scale;
}

vec3 wsgi_getBufferPosition(const in vec3 localPos, const in int voxelScale) {
    float voxelSize = wsgi_getVoxelSize(voxelScale);
    vec3 interval = wsgi_getStepInterval(ap.camera.pos);
    return (localPos + interval) / voxelSize + WSGI_BufferCenter;
}

vec3 wsgi_getLocalPosition(const in vec3 bufferPos, const in int voxelScale) {
    float voxelSize = wsgi_getVoxelSize(voxelScale);
    vec3 interval = wsgi_getStepInterval(ap.camera.pos);
    return (bufferPos - WSGI_BufferCenter) * voxelSize - interval;
}

bool wsgi_isInBounds(const in ivec3 bufferPos) {
    return clamp(bufferPos, 0, LIGHTING_GI_SIZE-1) == bufferPos;
}

bool wsgi_isInBounds(const in vec3 bufferPos) {
    return clamp(bufferPos, 0.5, LIGHTING_GI_SIZE-0.5) == bufferPos;
}

int wsgi_getBufferIndex(const in ivec3 bufferPos, const in int cascade) {
	const ivec3 flatten = ivec3(1, LIGHTING_GI_SIZE, LIGHTING_GI_SIZE*LIGHTING_GI_SIZE);
    const int cascadeSize = LIGHTING_GI_SIZE*LIGHTING_GI_SIZE*LIGHTING_GI_SIZE;
	return sumOf(flatten * bufferPos) + (cascade * cascadeSize);
}
