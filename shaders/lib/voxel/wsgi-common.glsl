const ivec3 WSGI_BufferSize = ivec3(LIGHTING_GI_SIZE);
const ivec3 WSGI_BufferCenter = WSGI_BufferSize / 2;
const ivec3 WSGI_VoxelOffset = VoxelBufferCenter - WSGI_BufferCenter;


vec3 wsgi_getBufferCenter(const in vec3 cameraPos) {
    return WSGI_BufferCenter + fract(cameraPos);
}

vec3 wsgi_getBufferPosition(const in vec3 localPos) {
    return localPos + wsgi_getBufferCenter(ap.camera.pos);
}

vec3 wsgi_getLocalPosition(const in vec3 bufferPos) {
    return bufferPos - wsgi_getBufferCenter(ap.camera.pos);
}

bool wsgi_isInBounds(const in ivec3 bufferPos) {
    return clamp(bufferPos, 0, LIGHTING_GI_SIZE-1) == bufferPos;
}

bool wsgi_isInBounds(const in vec3 bufferPos) {
    return clamp(bufferPos, 0.5, LIGHTING_GI_SIZE-0.5) == bufferPos;
}

int wsgi_getBufferIndex(ivec3 bufferPos) {
	const ivec3 flatten = ivec3(1, LIGHTING_GI_SIZE, LIGHTING_GI_SIZE*LIGHTING_GI_SIZE);
	return sumOf(flatten * bufferPos);
}
