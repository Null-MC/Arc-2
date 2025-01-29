#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

layout(location = 0) out vec4 outColor;

uniform sampler2D TEX_SRC;
uniform sampler2D mainDepthTex;

in vec2 uv;

#include "/lib/common.glsl"
//#include "/lib/buffers/scene.glsl"
#include "/lib/noise/ign.glsl"

#ifdef EFFECT_TAA_ENABLED
//    #include "/lib/taa_jitter.glsl"
#endif

const int BLUR_SAMPLES = 8;
const float BLUR_RADIUS = 32.0;


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    vec3 colorFinal = texelFetch(TEX_SRC, iuv, 0).rgb;

    if (ap.camera.fluid == 1) {
        float depth = texelFetch(mainDepthTex, iuv, 0).r;
        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            //unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        float viewDist = length(viewPos);
        //vec3 localPos = mul3(ap.camera.viewInv, viewPos);

        #ifdef EFFECT_TAA_ENABLED
            float dither = InterleavedGradientNoiseTime(ivec2(gl_FragCoord.xy));
        #else
            float dither = InterleavedGradientNoise(ivec2(gl_FragCoord.xy));
        #endif

        float blurF = min(viewDist * 0.05, 1.0);

        vec2 pixelSize = 1.0 / ap.game.screenSize;
        float max_radius = mix(0.0, BLUR_RADIUS, blurF);

        float rotatePhase = dither * TAU;
        float rStep = max_radius / BLUR_SAMPLES;
        float radius = rStep * dither;

        vec3 colorBlur = vec3(0.0);
        for (int i = 0; i < BLUR_SAMPLES; i++) {
            vec2 offset = radius * vec2(
                sin(rotatePhase),
                cos(rotatePhase));

            radius += rStep;
            rotatePhase += GoldenAngle;
            vec2 sampleUV = uv + offset * pixelSize;

            // TODO: depth reject

            colorBlur += textureLod(TEX_SRC, sampleUV, 0).rgb;
        }

        colorBlur /= BLUR_SAMPLES;

        colorFinal = mix(colorFinal, colorBlur, blurF);
    }

    outColor = vec4(colorFinal, 1.0);
}
