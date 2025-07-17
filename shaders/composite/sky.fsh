#version 430 core
#extension GL_ARB_derivative_control: enable

#include "/settings.glsl"
#include "/lib/constants.glsl"

layout(location = 0) out vec4 outColor;

in vec2 uv;

uniform sampler2D solidDepthTex;

uniform sampler2D texSkyView;
uniform sampler2D texSkyTransmit;

uniform sampler3D texFogNoise;

#ifdef WORLD_END
    uniform sampler2D texEndSun;
    uniform sampler2D texEarth;
    uniform sampler2D texEarthSpecular;
#elif defined(WORLD_SKY_ENABLED)
    uniform sampler2D texMoon;
#endif

#include "/lib/common.glsl"
#include "/lib/buffers/scene.glsl"

#include "/lib/sampling/erp.glsl"
#include "/lib/hg.glsl"

#include "/lib/utility/blackbody.glsl"
#include "/lib/utility/matrix.glsl"
#include "/lib/utility/dfd-normal.glsl"

#include "/lib/light/hcm.glsl"
#include "/lib/light/fresnel.glsl"
#include "/lib/light/sampling.glsl"
#include "/lib/light/brdf.glsl"

#include "/lib/sky/common.glsl"
#include "/lib/sky/view.glsl"
#include "/lib/sky/sun.glsl"
#include "/lib/sky/stars.glsl"
#include "/lib/sky/density.glsl"
#include "/lib/sky/transmittance.glsl"

#ifdef WORLD_END
    #include "/lib/sky/sky-end.glsl"
#elif defined(WORLD_SKY_ENABLED)
    #include "/lib/sky/sky-overworld.glsl"
#endif

#include "/lib/sky/render.glsl"

#ifdef EFFECT_TAA_ENABLED
    #include "/lib/taa_jitter.glsl"
#endif


void main() {
    ivec2 iuv = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(solidDepthTex, iuv, 0).r;
    vec3 colorFinal = vec3(0.0);

    if (depth == 1.0) {
        vec3 ndcPos = vec3(uv, depth) * 2.0 - 1.0;

        #ifdef EFFECT_TAA_ENABLED
            unjitter(ndcPos);
        #endif

        vec3 viewPos = unproject(ap.camera.projectionInv, ndcPos);
        vec3 localPos = mul3(ap.camera.viewInv, viewPos);
        vec3 viewLocalDir = normalize(localPos);

        colorFinal = renderSky(vec3(0.0), viewLocalDir, false);
    }

    colorFinal = clamp(colorFinal * BufferLumScaleInv, 0.0, 65000.0);

    outColor = vec4(colorFinal, 1.0);
}
