const float ParallaxSharpThreshold = (1.5/255.0);
const float ParallaxDepthF = MATERIAL_PARALLAX_DEPTH * 0.01;


vec2 GetParallaxCoord(const in vec2 texcoord, const in mat2 dFdXY, const in vec3 tanViewDir, const in float viewDist, out float texDepth, out vec3 traceDepth) {
    // WARN: temp workaround
    vec2 atlasSize = textureSize(irisInt_normalMap, 0);

    vec2 stepCoord = tanViewDir.xy * ParallaxDepthF / (fma(tanViewDir.z, MATERIAL_PARALLAX_SAMPLES, 1.0));
    const float stepDepth = 1.0 / MATERIAL_PARALLAX_SAMPLES;

    #if DISPLACE_MODE == DISPLACE_POM_SMOOTH
        vec2 atlasPixelSize = 1.0 / atlasSize;
        float prevTexDepth;
    #endif

    float viewDistF = 1.0 - saturate(viewDist / MATERIAL_PARALLAX_MAXDIST);
    float maxSampleCount = fma(viewDistF, MATERIAL_PARALLAX_SAMPLES, 0.5);

    vec2 localSize = atlasSize * (vIn.atlasMaxCoord - vIn.atlasMinCoord);
    if (all(greaterThan(localSize, vec2(EPSILON))))
        stepCoord.y *= localSize.x / localSize.y;

    float i;
    texDepth = 1.0;
    float depthDist = 1.0;
    for (i = 0.0; i < (MATERIAL_PARALLAX_SAMPLES+0.5); i += 1.0) {
        if (i > maxSampleCount || depthDist < (1.0/255.0)) break;

        #if DISPLACE_MODE == DISPLACE_POM_SMOOTH
            prevTexDepth = texDepth;
        #endif

        vec2 localTraceCoord = fma(vec2(i), -stepCoord, texcoord);

        #ifdef MATERIAL_PARALLAX_SMOOTH
            vec2 uv[4];
            vec2 atlasTileSize = vIn.atlasBounds[1] * atlasSize;
            vec2 f = GetLinearCoords(localTraceCoord, atlasTileSize, uv);

            uv[0] = GetAtlasCoord(uv[0], vIn.atlasBounds);
            uv[1] = GetAtlasCoord(uv[1], vIn.atlasBounds);
            uv[2] = GetAtlasCoord(uv[2], vIn.atlasBounds);
            uv[3] = GetAtlasCoord(uv[3], vIn.atlasBounds);

            texDepth = TextureGradLinear(irisInt_normalMap, uv, dFdXY, f, 3);
        #else
            vec2 traceAtlasCoord = GetAtlasCoord(localTraceCoord, vIn.atlasMinCoord, vIn.atlasMaxCoord);
            texDepth = textureGrad(irisInt_normalMap, traceAtlasCoord, dFdXY[0], dFdXY[1]).a;
        #endif

        depthDist = 1.0 - fma(i, stepDepth, texDepth);
    }

    i = max(i - 1.0, 0.0);
    float pI = max(i - 1.0, 0.0);

    #ifdef MATERIAL_PARALLAX_SMOOTH
        vec2 currentTraceOffset = texcoord - i * stepCoord;
        float currentTraceDepth = max(1.0 - i * stepDepth, 0.0);
        vec2 prevTraceOffset = texcoord - pI * stepCoord;
        float prevTraceDepth = max(1.0 - pI * stepDepth, 0.0);

        float t = (prevTraceDepth - prevTexDepth) / max(texDepth - prevTexDepth + prevTraceDepth - currentTraceDepth, EPSILON);
        t = clamp(t, 0.0, 1.0);

        traceDepth.xy = mix(prevTraceOffset, currentTraceOffset, t);
        traceDepth.z = mix(prevTraceDepth, currentTraceDepth, t);
    #else
        traceDepth.xy = texcoord - pI * stepCoord;
        traceDepth.z = max(1.0 - pI * stepDepth, 0.0);
    #endif

    #ifdef MATERIAL_PARALLAX_SMOOTH
        return GetAtlasCoord(traceDepth.xy, vIn.atlasMinCoord, vIn.atlasMaxCoord);
    #else
        return GetAtlasCoord(texcoord - i * stepCoord, vIn.atlasMinCoord, vIn.atlasMaxCoord);
    #endif
}

#ifdef MATERIAL_PARALLAX_SHARP
    vec3 GetParallaxSlopeNormal(const in vec2 atlasCoord, const in mat2 dFdXY, const in float traceDepth, const in vec3 tanViewDir) {
        // WARN: temp workaround
        vec2 atlasSize = textureSize(irisInt_normalMap, 0);

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

        vec2 tX = GetLocalCoord(fma(tex_x, atlasPixelSize, atlasCoord), vIn.atlasMinCoord, vIn.atlasMaxCoord);
        tX = GetAtlasCoord(tX, vIn.atlasMinCoord, vIn.atlasMaxCoord);

        vec2 tY = GetLocalCoord(fma(tex_y, atlasPixelSize, atlasCoord), vIn.atlasMinCoord, vIn.atlasMaxCoord);
        tY = GetAtlasCoord(tY, vIn.atlasMinCoord, vIn.atlasMaxCoord);

        float height_x = textureGrad(irisInt_normalMap, tX, dFdXY[0], dFdXY[1]).a;
        float height_y = textureGrad(irisInt_normalMap, tY, dFdXY[0], dFdXY[1]).a;
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
