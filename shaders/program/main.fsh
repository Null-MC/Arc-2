#version 430

layout(location = 0) out vec4 outColor;
layout(location = 1) out uvec2 outData;

in vec2 uv;
in vec2 light;
in vec4 color;
in vec3 localPos;
in vec3 localOffset;
in vec3 localNormal;
// in vec3 shadowViewPos;
flat in int material;

#include "/settings.glsl"
#include "/lib/common.glsl"

#ifdef RENDER_TRANSLUCENT
    #include "/lib/fresnel.glsl"
    #include "/lib/water_waves.glsl"
#endif


void iris_emitFragment() {
    vec2 mUV = uv;
    vec2 mLight = light;
    vec4 mColor = color;
    iris_modifyBase(mUV, mColor, mLight);

    vec3 _localNormal = normalize(localNormal);

    vec4 albedo = iris_sampleBaseTex(mUV);

    bool isWater = false;
    #ifdef RENDER_TRANSLUCENT
        isWater = bitfieldExtract(material, 6, 1) != 0;

        if (isWater) {
            #ifdef WATER_WAVES_ENABLED
                const float lmcoord_y = 1.0;

                vec3 waveOffset = GetWaveHeight(localPos + cameraPos, lmcoord_y, timeCounter, 24);

                // mUV += 0.1*waveOffset.xz;

                vec3 wavePos = localPos;
                wavePos.y += waveOffset.y - localOffset.y;

                vec3 dX = dFdx(wavePos);
                vec3 dY = dFdy(wavePos);
                _localNormal = normalize(cross(dX, dY));
            #endif

            // vec3 localViewDir = normalize(localPos);
            // float NoVm = max(dot(localNormal, -localViewDir), 0.0);
            // float F = F_schlick(NoVm, 0.02, 1.0);

            albedo.a = 0.02; //F;
        }
    #endif

    if (iris_discardFragment(albedo)) {discard; return;}

    albedo *= mColor;

    #ifdef DEBUG_WHITE_WORLD
        albedo.rgb = vec3(1.0);
    #endif

    vec2 lmcoord = clamp((mLight - (0.5/16.0)) / (15.0/16.0), 0.0, 1.0);

    #ifndef RENDER_TRANSLUCENT
        albedo.a = 1.0;
    #endif

    outColor = albedo;

    outData.r = packUnorm4x8(vec4(_localNormal * 0.5 + 0.5, (material + 0.5) / 255.0));
    outData.g = packUnorm4x8(vec4(lmcoord, isWater ? 1.0 : 0.0, 0.0));
}
