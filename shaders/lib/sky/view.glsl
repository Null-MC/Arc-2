vec3 getValFromSkyLUT(const in sampler2D texSkyView, vec3 skyPos, vec3 rayDir, vec3 sunDir) {
    float height = length(skyPos);
    vec3 up = skyPos / height;

    float elevation2 = max(height * height - groundRadiusMM * groundRadiusMM, 0.0);
    float horizonAngle = safeacos(sqrt(elevation2) / height);
    float altitudeAngle = horizonAngle - acos(dot(rayDir, up)); // Between -PI/2 and PI/2
    float azimuthAngle; // Between 0 and 2*PI
    if (abs(altitudeAngle) > (0.5*PI - 0.0001)) {
        // Looking nearly straight up or down.
        azimuthAngle = 0.0;
    } else {
        vec3 right = cross(sunDir, up);
        vec3 forward = cross(up, right);
        
        vec3 projectedDir = normalize(rayDir - up*(dot(rayDir, up)));
        float sinTheta = dot(projectedDir, right);
        float cosTheta = dot(projectedDir, forward);
        azimuthAngle = atan(sinTheta, cosTheta) + PI;
    }
    
    // Non-linear mapping of altitude angle. See Section 5.3 of the paper.
    float v = 0.5 + 0.5*sign(altitudeAngle) * sqrt(abs(altitudeAngle) * 2.0/PI);
    vec2 uv = vec2(azimuthAngle / (2.0*PI), v);
    // uv *= skyLUTRes;
    // uv /= iChannelResolution[1].xy;
    
    return textureLod(texSkyView, uv, 0).rgb * BufferLumScale;
}
