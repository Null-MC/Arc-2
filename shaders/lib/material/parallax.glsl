const float ParallaxSharpThreshold = (1.5/255.0);
//const float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01;


vec2 GetParallaxCoord(const in vec2 texcoord, const in float LOD, const in vec3 tanViewDir, const in float viewDist, out float texDepth, out vec3 traceDepth) {
    // WARN: temp workaround
    vec2 atlasSize = textureSize(irisInt_NormalMap, 0);

    #ifdef MATERIAL_PARALLAX_OPTIMIZE
        vec2 atlasCoord = GetAtlasCoord(texcoord, vIn.atlasCoordMin, vIn.atlasCoordSize);
        vec2 atlasSize1 = textureSize(irisInt_NormalMap, 2);
        float maxTexDepth = 1.0 - texelFetch(irisInt_NormalMap, ivec2(atlasCoord * atlasSize1), 2).a;
        maxTexDepth = sqrt(maxTexDepth);
    #else
        const float maxTexDepth = 1.0;
    #endif

    float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01 * maxTexDepth;
    vec2 stepCoord = tanViewDir.xy * ParallaxDepthF / (fma(tanViewDir.z, MATERIAL_PARALLAX_SAMPLES, 1.0));
    float stepDepth = maxTexDepth / MATERIAL_PARALLAX_SAMPLES;

    #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH
        vec2 atlasPixelSize = 1.0 / atlasSize;
        float prevTexDepth;
    #endif

    float viewDistF = 1.0 - saturate(viewDist / MATERIAL_PARALLAX_MAXDIST);
    float maxSampleCount = fma(viewDistF, MATERIAL_PARALLAX_SAMPLES, 0.5);

    vec2 localSize = atlasSize * vIn.atlasCoordSize;
    if (all(greaterThan(localSize, vec2(EPSILON))))
        stepCoord.y *= localSize.x / localSize.y;

    int i;
    texDepth = 1.0;
    float depthDist = 1.0;
    for (i = 0; i < MATERIAL_PARALLAX_SAMPLES; i++) {
        if (i > maxSampleCount || depthDist < (1.0/255.0)) break;

        #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH
            prevTexDepth = texDepth;
        #endif

        vec2 localTraceCoord = fma(vec2(i), -stepCoord, texcoord);

        #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH
            vec2 uv[4];
            vec2 atlasTileSize = vIn.atlasCoordSize * atlasSize;
            vec2 f = GetLinearCoords(localTraceCoord, atlasTileSize, uv);

            uv[0] = GetAtlasCoord(uv[0], vIn.atlasCoordMin, vIn.atlasCoordSize);
            uv[1] = GetAtlasCoord(uv[1], vIn.atlasCoordMin, vIn.atlasCoordSize);
            uv[2] = GetAtlasCoord(uv[2], vIn.atlasCoordMin, vIn.atlasCoordSize);
            uv[3] = GetAtlasCoord(uv[3], vIn.atlasCoordMin, vIn.atlasCoordSize);

            texDepth = TextureLodLinear(irisInt_NormalMap, uv, LOD, f, 3);
        #else
            vec2 traceAtlasCoord = GetAtlasCoord(localTraceCoord, vIn.atlasCoordMin, vIn.atlasCoordSize);
            texDepth = iris_sampleNormalMapLod(traceAtlasCoord, int(LOD)).a;
        #endif

        depthDist = 1.0 - fma(i, stepDepth, texDepth);
    }

    i = max(i - 1, 0);
    float pI = max(i - 1, 0);

    #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH
        vec2 currentTraceOffset = texcoord - i * stepCoord;
        float currentTraceDepth = max(1.0 - i * stepDepth, 0.0);
        vec2 prevTraceOffset = texcoord - pI * stepCoord;
        float prevTraceDepth = max(1.0 - pI * stepDepth, 0.0);

        float t = (prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON);
        t = saturate(t);

        traceDepth.xy = mix(prevTraceOffset, currentTraceOffset, t);
        traceDepth.z = mix(prevTraceDepth, currentTraceDepth, t);
    #else
        traceDepth.xy = texcoord - pI * stepCoord;
        traceDepth.z = max(1.0 - pI * stepDepth, 0.0);
    #endif

    #if MATERIAL_PARALLAX_TYPE == POM_TYPE_SMOOTH
        return GetAtlasCoord(traceDepth.xy, vIn.atlasCoordMin, vIn.atlasCoordSize);
    #else
        return GetAtlasCoord(texcoord - i * stepCoord, vIn.atlasCoordMin, vIn.atlasCoordSize);
    #endif
}

#if MATERIAL_PARALLAX_TYPE == POM_TYPE_SHARP
    vec3 GetParallaxSlopeNormal(const in vec2 atlasCoord, const in float LOD, const in float traceDepth, const in vec3 tanViewDir) {
        // WARN: temp workaround
        vec2 atlasSize = textureSize(irisInt_NormalMap, 0);

        vec2 atlasPixelSize = 1.0 / atlasSize;
        float atlasAspect = atlasSize.x / atlasSize.y;

        vec2 tex_snapped = floor(atlasCoord * atlasSize) * atlasPixelSize;
        vec2 tex_offset = atlasCoord - (fma(atlasPixelSize, vec2(0.5), tex_snapped));

        vec2 stepSign = sign(tex_offset);
        vec2 viewSign = sign(-tanViewDir.xy);

        bool dir = abs(tex_offset.x  * atlasAspect) < abs(tex_offset.y);
        vec2 tex_x, tex_y;

        if (dir) {
            tex_x = vec2(viewSign.x, 0.0);
            tex_y = vec2(0.0, stepSign.y);
        }
        else {
            tex_x = vec2(stepSign.x, 0.0);
            tex_y = vec2(0.0, viewSign.y);
        }

        vec2 tX = GetLocalCoord(fma(tex_x, atlasPixelSize, atlasCoord), vIn.atlasCoordMin, vIn.atlasCoordSize);
        tX = GetAtlasCoord(tX, vIn.atlasCoordMin, vIn.atlasCoordSize);

        vec2 tY = GetLocalCoord(fma(tex_y, atlasPixelSize, atlasCoord), vIn.atlasCoordMin, vIn.atlasCoordSize);
        tY = GetAtlasCoord(tY, vIn.atlasCoordMin, vIn.atlasCoordSize);

        float height_x = iris_sampleNormalMapLod(tX, int(LOD)).a;
        float height_y = iris_sampleNormalMapLod(tY, int(LOD)).a;
        vec3 signMask = vec3(0.0);

        if (dir) {
            if (!(traceDepth > height_y && -viewSign.y != stepSign.y)) {
                if (traceDepth > height_x)
                    signMask.x = 1.0;
                else if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    signMask.y = 1.0;
                else
                    signMask.x = 1.0;
            }
            else {
                signMask.y = 1.0;
            }
        }
        else {
            if (!(traceDepth > height_x && -viewSign.x != stepSign.x)) {
                if (traceDepth > height_y)
                    signMask.y = 1.0;
                else if (abs(tanViewDir.y) > abs(tanViewDir.x))
                    signMask.y = 1.0;
                else
                    signMask.x = 1.0;
            }
            else {
                signMask.x = 1.0;
            }
        }

        return signMask * vec3(viewSign, 0.0);
    }
#endif
