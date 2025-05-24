const mat3 RGB_TO_XYZ = mat3(
    0.4124564, 0.2126729, 0.0193339,
    0.3575761, 0.7151522, 0.1191920,
    0.1804375, 0.0721750, 0.9503041);

const mat3 XYZ_TO_RGB = mat3(
     3.2404542,-0.9692660, 0.0556434,
    -1.5371385, 1.8760108,-0.2040259,
    -0.4985314, 0.0415560, 1.0572252);

float Exposure_logLumRange = Scene_PostExposureMax - Scene_PostExposureMin;
float Exposure_logLumRangeInv = 1.0 / Exposure_logLumRange;
//float Exposure_numPixels = ap.game.screenSize.x * ap.game.screenSize.y;


vec3 xyz_to_xyY(vec3 xyz) {
	float sum = sumOf(xyz);
    return vec3(xyz.xy / sum, xyz.y);
}

vec3 xyY_to_xyz(vec3 xyY) {
    vec2 xz = vec2(xyY.x, 1.0 - xyY.x - xyY.y);
    return vec3(xyY.z * xz.xy / xyY.y, xyY.z).xzy;
}

//float reinhard2(const in float color, const in float L_white) {
//    return (color * (1.0 + color / _pow2(L_white))) / (1.0 + color);
//}

float ev_100(const in float luminance, const in float luminance_avg) {
    return luminance / (9.6 * max(luminance_avg, 1.0e-8));
}

void ApplyAutoExposure(inout vec3 rgb, const in float avgLum) {
	vec3 xyY = xyz_to_xyY(RGB_TO_XYZ * rgb);

	//float lp = xyY.z / (9.6 * avgLum + 0.0001);
    float lp = ev_100(xyY.z, avgLum);

	//const float whitePoint = Scene_PostExposureRange;
    //xyY.z = reinhard2(lp, whitePoint);
    xyY.z = lp * exp2(-Post_ExposureOffset);// * 0.08;

	rgb = XYZ_TO_RGB * xyY_to_xyz(xyY);
}
