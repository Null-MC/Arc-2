#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec3 out_color;

uniform sampler2D mainDepthTex;
uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/noise/ign.glsl"
#include "/lib/sampling/depth.glsl"


float getBlurSize(const in float depth, const in float focusPoint) {
    float coc = 1.0/focusPoint - 1.0/depth;
    return abs(coc) * Effect_DOF_Radius;
}


void main() {
    vec3 color = textureLod(TEX_SRC, uv, 0).rgb;
    float baseDepth = textureLod(mainDepthTex, uv, 0).r;
    baseDepth = linearizeDepth(baseDepth, ap.camera.near, ap.camera.far);

    float centerSize = getBlurSize(baseDepth, Scene_FocusDepth);

    vec2 pixelSize = 1.0 / ap.game.screenSize;
    //float stepSize = Effect_DOF_Radius / EFFECT_DOF_SAMPLES * 2.0;
    //float radius = stepSize;
    float tot = 1.0;

    // TODO: jitter initial angle?
    float dither = InterleavedGradientNoise(gl_FragCoord.xy);//GetShadowDither();
    float angle = dither * TAU;
    float s = sin(angle), c = cos(angle);
    mat2 rotation = mat2(c, -s, s, c);

    const float GoldenAngle = PI * (3.0 - sqrt(5.0));
    const float PHI = (1.0 + sqrt(5.0)) / 2.0;

//    float ang = 0.0;
//    for (float ang = 0.0; radius < Effect_DOF_Radius; ang += GoldenAngle) {
    for (int i = 0; i < EFFECT_DOF_SAMPLES; i++) {
        //vec2 tc = uv + vec2(cos(ang), sin(ang)) * texelSize * radius;

        float radius = sqrt((i + 0.5) / EFFECT_DOF_SAMPLES);
        float theta = i * GoldenAngle + PHI;

        vec2 diskOffset = radius * vec2(cos(theta), sin(theta));
        vec2 pixelOffset = (rotation * diskOffset) * Effect_DOF_Radius;
        vec2 tc = uv + pixelOffset * pixelSize;

        vec3 sampleColor = textureLod(TEX_SRC, tc, 0).rgb;
        float sampleDepth = textureLod(mainDepthTex, tc, 0).r;
        sampleDepth = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);

        float sampleSize = getBlurSize(sampleDepth, Scene_FocusDepth);

        if (sampleDepth > Scene_FocusDepth)
            sampleSize = clamp(sampleSize, 0.0, centerSize*2.0);

        float m = smoothstep(radius-0.5, radius+0.5, sampleSize);
        color += mix(color / tot, sampleColor, m);
        //radius += stepSize / radius;

        tot += 1.0;
        //ang += GoldenAngle;
    }

    color /= tot;

    out_color = color;
}
