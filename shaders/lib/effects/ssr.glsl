const int SSR_MAXSTEPS = 32;
const int SSR_LOD_MAX = 2;


// returns: xyz=clip-pos  w=attenuation
vec4 GetReflectionPosition(const in sampler2D depthtex, const in vec3 clipPos, const in vec3 clipRay) {
    float screenRayLength = length(clipRay.xy);
    if (screenRayLength < EPSILON) return vec4(clipPos, 0.0);

    vec3 screenRay = clipRay / screenRayLength;

    // #ifdef EFFECT_TAA_ENABLED
        float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
    // #else
    //     float dither = InterleavedGradientNoise();
    // #endif

    float startDepthLinear = linearizeDepth(clipPos.z, ap.camera.near, ap.camera.far);

    vec2 pixelSize = 1.0 / ap.game.screenSize;

    vec2 screenRayAbs = abs(screenRay.xy);
    vec2 pixelRay = pixelSize / screenRayAbs.xy;
    vec3 rayX = screenRay * pixelRay.x;
    vec3 rayY = screenRay * pixelRay.y;
    screenRay = mix(rayX, rayY, screenRayAbs.y);

    screenRay *= 20.0;

    vec3 lastTracePos = screenRay * (1.0 + dither) + clipPos;
    vec3 lastVisPos = lastTracePos;

    const vec3 clipMin = vec3(0.0, 0.0, EPSILON);
    vec3 clipMax = vec3(1.0) - vec3(pixelSize, EPSILON);

    float alpha = 0.0;
    float texDepth;
    vec3 tracePos;

    for (int i = 0; i < SSR_MAXSTEPS; i++) {
        tracePos = screenRay + lastTracePos;

        vec3 t = clamp(tracePos, clipMin, clipMax);
        if (t != tracePos) {
            lastVisPos = t;

            // allow sky reflection
            if (tracePos.z >= 1.0 && t.xy == tracePos.xy) alpha = 1.0;

            break;
        }

        float sampleDepth = textureLod(depthtex, tracePos.xy, 0).r;
        float sampleDepthL = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);
        float traceDepthL = linearizeDepth(tracePos.z, ap.camera.near, ap.camera.far);

        if (traceDepthL < sampleDepthL + 0.002) {
            lastTracePos = tracePos;
            continue;
        }

        if (sampleDepth > clipPos.z && screenRay.z < 0.0) {
            lastTracePos = tracePos;
            continue;
        }

        lastVisPos = tracePos;
        alpha = 1.0;
        break;
    }

    const int SSR_REFINE_STEPS = 8;

    screenRay /= SSR_REFINE_STEPS;

    for (int i = 0; i < SSR_REFINE_STEPS; i++) {
        tracePos = screenRay + lastTracePos;

        vec3 t = clamp(tracePos, clipMin, clipMax);
        if (t != tracePos) {
            lastVisPos = t;

            // allow sky reflection
            if (tracePos.z >= 1.0 && t.xy == tracePos.xy) alpha = 1.0;

            break;
        }

        float sampleDepth = textureLod(depthtex, tracePos.xy, 0).r;
        float sampleDepthL = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);
        float traceDepthL = linearizeDepth(tracePos.z, ap.camera.near, ap.camera.far);

        if (traceDepthL < sampleDepthL + 0.002) {
            lastTracePos = tracePos;
            continue;
        }

        if (sampleDepth > clipPos.z && screenRay.z < 0.0) {
            lastTracePos = tracePos;
            continue;
        }

        lastVisPos = tracePos;
        alpha = 1.0;
        break;
    }

    return vec4(lastVisPos, alpha);
}

// uv=tracePos.xy
vec3 GetRelectColor(const in sampler2D tex, const in vec2 uv, inout float alpha, const in float lod) {
    vec3 color = vec3(0.0);

    if (alpha > EPSILON) {
        vec2 alphaXY = saturate(12.0 * abs(vec2(0.5) - uv) - 5.0);
        alpha = maxOf(alphaXY);
        alpha = 1.0 - pow(alpha, 4);

        color = textureLod(tex, uv, lod).rgb * 1000.0;
    }

    return color;
}
