const float wavingScale = 8.0;
const float wavingHeight = 0.6;

vec3 waving_fbm(const in vec3 worldPos) {
    vec2 position = worldPos.xz / wavingScale;

    float iter = 0.0;
    float frequency = 3.0;
    float speed = 1.0;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;

    float time = ap.time.elapsed / 3.6;
    
    for (int i = 0; i < 8; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + time * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        position -= force * 0.03;
        height += wave * weight;
        iter += 12.0;
        waveSum += weight;
        weight *= 0.8;
        frequency *= 1.1;
        speed *= 1.3;
    }

    position = (position * wavingScale) - worldPos.xz;
    return vec3(position.x, height / waveSum * wavingHeight - 0.5 * wavingHeight, position.y);
}

void ApplyWavingOffset(inout vec3 localPos, const in uint blockId) {
    uint attachment = 0u;
    float range = 0.0;//GetWavingRange(blockId, attachment);

    if (iris_hasTag(blockId, TAG_FOLIAGE)) range = 1.0;

    if (range < EPSILON) return;

//    #if defined RENDER_SHADOW
//    vec3 localPos = (shadowModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;
//    vec3 worldPos = localPos + cameraPosition;
//    #else
//    vec3 localPos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz;
//    vec3 worldPos = localPos + cameraPosition;
//    #endif

    vec3 worldPos = localPos + ap.camera.pos;

    vec3 offset = waving_fbm(worldPos);

//    if (attachment != 0u) {
//        float attachOffset = 0.0;
//        switch (attachment) {
//            case 1u:
//            attachOffset = 0.5;
//            break;
//            case 2u:
//            attachOffset = -0.5;
//            break;
//        }
//
//        float baseOffset = -at_midBlock.y / 64.0 + attachOffset;
//        offset *= clamp(baseOffset, 0.0, 1.0);
//    }

    localPos += offset;// * range * strength;
}
