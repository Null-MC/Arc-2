const float lmCoordMin = ( 0.5/16.0);
const float lmCoordMax = (15.5/16.0);
const float lmCoordRange = lmCoordMax - lmCoordMin;


vec2 LightMapNorm(vec2 lightCoord) {
    return (lightCoord - lmCoordMin) / lmCoordRange;
}

vec2 LightMapTex(vec2 lightNorm) {
    return fma(saturate(lightNorm), vec2(lmCoordRange), vec2(lmCoordMin));
}
