#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec3 out_color;

uniform sampler2D mainDepthTex;
uniform sampler2D TEX_SRC;

in vec2 uv;

#include "/lib/common.glsl"

#include "/lib/noise/ign.glsl"
//#include "/lib/noise/blue.glsl"
#include "/lib/noise/hash.glsl"

#include "/lib/sampling/depth.glsl"

//#ifdef EFFECT_TAA_ENABLED
//    #include "/lib/taa_jitter.glsl"
//#endif


#define DOF_SCALE 4.0 // [1.0 1.5 2.0 2.5 3.0 3.5 4.0 4.5 5.0]
// Smaller = nicer blur, larger = faster
#define DOF_STEP_SIZE 0.5 // [0.5 1.0 1.5 2.0]
#define DOF_MAX_SIZE 10.0 // [5.0 10.0 15.0 20.0 25.0 30.0]


float getBlurSize(const in float depth, const in float focusPoint) {
    float coc = 1.0/focusPoint - 1.0/depth;
    return saturate(abs(coc) * DOF_SCALE) * DOF_MAX_SIZE;
}


void main() {
    //ivec2 iuv = ivec2(uv * ap.game.screenSize);
    //float depth = texelFetch(mainDepthTex, iuv, 0).r;

    // vec2 uv_j = uv;
    // #ifdef EFFECT_TAA_ENABLED
    //     vec2 jitterOffset = getJitterOffset(ap.time.frames);
    //     uv_j -= jitterOffset;
    // #endif

    float centerDepth = textureLod(mainDepthTex, vec2(0.5), 0).r;
    centerDepth = linearizeDepth(centerDepth, ap.camera.near, ap.camera.far);

    vec3 color = textureLod(TEX_SRC, uv, 0).rgb;
    float baseDepth = textureLod(mainDepthTex, uv, 0).r;
    baseDepth = linearizeDepth(baseDepth, ap.camera.near, ap.camera.far);

    // TODO: make dynamic based on focus distance
    //float focusScale = DOF_SCALE; //clamp(0.1 * focusPoint, 1.0, 20.0); //4.0;

    float centerSize = getBlurSize(baseDepth, centerDepth);

    vec2 texelSize = 1.0 / ap.game.screenSize;
    float radius = DOF_STEP_SIZE;
    float tot = 1.0;

    for (float ang = 0.0; radius < DOF_MAX_SIZE; ang += GoldenAngle) {
        vec2 tc = uv + vec2(cos(ang), sin(ang)) * texelSize * radius;

        vec3 sampleColor = textureLod(TEX_SRC, tc, 0).rgb;
        float sampleDepth = textureLod(mainDepthTex, tc, 0).r;
        sampleDepth = linearizeDepth(sampleDepth, ap.camera.near, ap.camera.far);

        float sampleSize = getBlurSize(sampleDepth, centerDepth);

        if (sampleDepth > centerDepth)
            sampleSize = clamp(sampleSize, 0.0, centerSize*2.0);

        float m = smoothstep(radius-0.5, radius+0.5, sampleSize);
        color += mix(color / tot, sampleColor, m);
        radius += DOF_STEP_SIZE / radius;

        tot += 1.0;
    }

    color /= tot;

    out_color = color;
}
