#version 430 core

layout(location = 0) out vec4 outColor;

// in vec2 uv;

// uniform sampler2D texSkyTransmit;
// uniform sampler2D texSkyView;

// #include "/settings.glsl"
#include "/lib/common.glsl"

// #include "/lib/utility/blackbody.glsl"
// #include "/lib/utility/matrix.glsl"

// #include "/lib/sky/common.glsl"
// #include "/lib/sky/view.glsl"
// #include "/lib/sky/stars.glsl"


// vec3 sun(vec3 rayDir, vec3 sunDir) {
//     const float sunSolidAngle = SUN_SIZE * (PI/180.0);
//     const float minSunCosTheta = cos(sunSolidAngle);

//     float cosTheta = dot(rayDir, sunDir);
//     if (cosTheta >= minSunCosTheta) return vec3(1.0);
    
//     return vec3(0.0);
// }


void iris_emitFragment() {
    // vec3 sunDir = normalize(mul3(playerModelViewInverse, sunPosition));
    
    // vec2 uv = gl_FragCoord.xy / screenSize;
    // vec3 ndcPos = vec3(uv, 1.0) * 2.0 - 1.0;
    // vec3 viewPos = unproject(playerProjectionInverse, ndcPos);
    // vec3 localPos = mul3(playerModelViewInverse, viewPos);
    // vec3 localViewDir = normalize(localPos);
    
    // vec3 skyPos = getSkyPosition(vec3(0.0));
    // vec3 colorFinal = 20.0 * getValFromSkyLUT(texSkyView, skyPos, localViewDir, sunDir);

    // if (rayIntersectSphere(skyPos, localViewDir, groundRadiusMM) < 0.0) {
    //     vec3 sunLum = 200.0 * sun(localViewDir, sunDir);

    //     vec3 starViewDir = getStarViewDir(localViewDir);
    //     vec3 starLight = 0.4 * GetStarLight(starViewDir);

    //     vec3 skyTransmit = getValFromTLUT(texSkyTransmit, skyPos, localViewDir);

    //     colorFinal += (sunLum + starLight) * skyTransmit;
    // }
    
    vec3 colorFinal = vec3(0.0);

    outColor = vec4(colorFinal, 1.0);
}
