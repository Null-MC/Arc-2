#version 430 core

#include "/lib/constants.glsl"
#include "/settings.glsl"

out VertexData2 {
    vec3 modelPos;
    flat bool isFull;
    vec2 uv;

    #ifdef IS_POINT_LIGHT_POM_ENABLED
        vec3 shadowViewPos;
        vec3 tangentViewPos;
        flat vec2 atlasCoordMin;
        flat vec2 atlasCoordSize;
    #endif
} vOut;

#include "/lib/common.glsl"

#ifdef SKY_WIND_ENABLED
    #include "/lib/noise/hash.glsl"
    #include "/lib/wind_waves.glsl"
#endif

#ifdef IS_POINT_LIGHT_POM_ENABLED
    #include "/lib/utility/tbn.glsl"
#endif


void iris_emitVertex(inout VertexData data) {
    vec3 shadowViewPos = mul3(iris_modelViewMatrix, data.modelPos.xyz);

    vOut.modelPos = data.modelPos.xyz;

    #ifdef SKY_WIND_ENABLED
        ap_PointLight light = iris_getPointLight(iris_currentPointLight);
        vec3 localPos = vOut.modelPos + light.pos;

        vec3 midPos = data.midBlock / 64.0;
        vec3 originPos = localPos + midPos;
        vec3 wavingOffset = GetWavingOffset(originPos, midPos, data.blockId);

        vOut.modelPos += wavingOffset;
        shadowViewPos = mul3(iris_modelViewMatrix, vOut.modelPos);
    #endif

    #ifdef IS_POINT_LIGHT_POM_ENABLED
        vOut.shadowViewPos = shadowViewPos;
    #endif

    data.clipPos = iris_projectionMatrix * vec4(shadowViewPos, 1.0);
}

void iris_sendParameters(in VertexData data) {
    vOut.uv = data.uv;

    ap_PointLight light = iris_getPointLight(iris_currentPointLight);
//    uint blockId = ap.point.block[iris_currentPointLight];
    vOut.isFull = iris_isFullBlock(light.block);

    #ifdef IS_POINT_LIGHT_POM_ENABLED
        // TODO: These are wrong! replace with old midcoord derived version
        vOut.atlasCoordMin = iris_getTexture(data.textureId).minCoord;
        vOut.atlasCoordSize = iris_getTexture(data.textureId).maxCoord - vOut.atlasCoordMin;

        vec3 viewNormal = mat3(iris_modelViewMatrix) * data.normal;
        vec3 viewTangent = mat3(iris_modelViewMatrix) * data.tangent.xyz;

        mat3 matViewTBN = GetTBN(viewNormal, viewTangent, data.tangent.w);

        vOut.tangentViewPos = vOut.shadowViewPos.xyz * matViewTBN;
    #endif
}
