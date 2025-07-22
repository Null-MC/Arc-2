vec3 sample_vndf_isotropic(vec3 localNormal, vec3 viewLocalDir, float alpha, vec2 u) {
    // decompose the floattor in parallel and perpendicular components
    vec3 wi_z = -localNormal * dot(viewLocalDir, localNormal);
    vec3 wi_xy = viewLocalDir + wi_z;

    // warp to the hemisphere configuration
    vec3 wiStd = -normalize(alpha * wi_xy + wi_z);

    // sample a spherical cap in (-wiStd.z, 1]
    float wiStd_z = dot(wiStd, localNormal);
    float z = 1.0 - u.y * (1.0 + wiStd_z);
    float sinTheta = sqrt(saturate(1.0f - z * z));
    float phi = TAU * u.x - PI;
    float x = sinTheta * cos(phi);
    float y = sinTheta * sin(phi);
    vec3 cStd = vec3(x, y, z);

    // reflect sample to align with normal
    vec3 up = vec3(0, 0, 1.000001); // Used for the singularity
    vec3 wr = localNormal + up;
    vec3 c = dot(wr, cStd) * wr / wr.z - cStd;

    // compute halfway direction as standard normal
    vec3 wmStd = c + wiStd;
    vec3 wmStd_z = localNormal * dot(localNormal, wmStd);
    vec3 wmStd_xy = wmStd_z - wmStd;

    // return final normal
    return normalize(alpha * wmStd_xy + wmStd_z);
}

vec3 sampleGGXVNDF(vec3 Ve, vec2 alpha, vec2 U) {
    // Section 3.2: transforming the view direction to the hemisphere configuration
    vec3 Vh = normalize(vec3(alpha * Ve.xy, Ve.z));
    // Section 4.1: orthonormal basis (with special case if cross product is zero)
    float lensq = Vh.x * Vh.x + Vh.y * Vh.y;
    vec3 T1 = lensq > 0.0 ? vec3(-Vh.y, Vh.x, 0) * inversesqrt(lensq) : vec3(1,0,0);
    vec3 T2 = cross(Vh, T1);
    // Section 4.2: parameterization of the projected area
    float r = sqrt(U.x);
    float phi = TAU * U.y;
    float t1 = r * cos(phi);
    float t2 = r * sin(phi);
    float s = 0.5 * (1.0 + Vh.z);
    t2 = (1.0 - s)*sqrt(1.0 - t1*t1) + s*t2;
    // Section 4.3: reprojection onto hemisphere
    vec3 Nh = t1*T1 + t2*T2 + sqrt(max(0.0, 1.0 - t1*t1 - t2*t2))*Vh;
    // Section 3.4: transforming the normal back to the ellipsoid configuration
    vec3 Ne = normalize(vec3(alpha * Nh.xy, max(0.0, Nh.z)));
    return Ne;
}
