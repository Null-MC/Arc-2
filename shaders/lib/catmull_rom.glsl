vec4 sampleHistoryCatmullRom(sampler2D texColor, const in vec2 uv) {
    vec2 samplePos = uv * ap.game.screenSize;// - 0.5;
    vec2 texPos1 = floor(samplePos);
    //vec2 f = samplePos - texPos1;
    vec2 f = fract(samplePos);

    //texPos1 += 0.5;

    // Compute the Catmull-Rom weights using the fractional offset that we calculated earlier.
    // These equations are pre-expanded based on our knowledge of where the texels will be located,
    // which lets us avoid having to evaluate a piece-wise function.
    vec2 w0 = f * ( -0.5 + f * (1.0 - 0.5*f));
    vec2 w1 = 1.0 + f * f * (-2.5 + 1.5*f);
    vec2 w2 = f * ( 0.5 + f * (2.0 - 1.5*f) );
    vec2 w3 = f * f * (-0.5 + 0.5 * f);

    // Work out weighting factors and sampling offsets that will let us use bilinear filtering to
    // simultaneously evaluate the middle 2 samples from the 4x4 grid.
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / max(w12, 0.001);

    w0 = clamp(w0, 0.0, 1.0);
    w12 = clamp(w12, 0.0, 1.0);
    w3 = clamp(w3, 0.0, 1.0);

    // Compute the final UV coordinates we'll use for sampling the texture
    vec2 pixelSize = 1.0 / ap.game.screenSize;
    vec2 texPos0  = (texPos1 - 1.0) * pixelSize;
    vec2 texPos3  = (texPos1 + 2.0) * pixelSize;
    vec2 texPos12 = (texPos1 + offset12) * pixelSize;

    vec4 result = vec4(0.0);

    result += textureLod(texColor, vec2(texPos0.x,  texPos0.y), 0) * w0.x * w0.y;
    result += textureLod(texColor, vec2(texPos12.x, texPos0.y), 0) * w12.x * w0.y;
    result += textureLod(texColor, vec2(texPos3.x,  texPos0.y), 0) * w3.x * w0.y;

    result += textureLod(texColor, vec2(texPos0.x,  texPos12.y), 0) * w0.x * w12.y;
    result += textureLod(texColor, vec2(texPos12.x, texPos12.y), 0) * w12.x * w12.y;
    result += textureLod(texColor, vec2(texPos3.x,  texPos12.y), 0) * w3.x * w12.y;

    result += textureLod(texColor, vec2(texPos0.x,  texPos3.y), 0) * w0.x * w3.y;
    result += textureLod(texColor, vec2(texPos12.x, texPos3.y), 0) * w12.x * w3.y;
    result += textureLod(texColor, vec2(texPos3.x,  texPos3.y), 0) * w3.x * w3.y;

    return result; //clamp(result, 0.0, 65000.0);
}
