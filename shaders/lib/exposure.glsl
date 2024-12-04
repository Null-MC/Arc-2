const mat3 RGB_TO_XYZ = mat3(
    0.4124564, 0.2126729, 0.0193339,
    0.3575761, 0.7151522, 0.1191920,
    0.1804375, 0.0721750, 0.9503041);

const mat3 XYZ_TO_RGB = mat3(
     3.2404542,-0.9692660, 0.0556434,
    -1.5371385, 1.8760108,-0.2040259,
    -0.4985314, 0.0415560, 1.0572252);

const float Exposure_minLogLum = -2.0;
const float Exposure_logLumRange = 1.0 / 3.0;
float Exposure_timeCoeff = 0.01; //timeCounter;
float Exposure_numPixels = screenSize.x * screenSize.y;


vec3 xyz_to_xyY(vec3 xyz) {
	float sum = xyz.x + xyz.y + xyz.z;
    return vec3(xyz.xy / sum, xyz.y);
}

vec3 xyY_to_xyz(vec3 xyY) {
    vec2 xz = vec2(xyY.x, 1.0 - xyY.x - xyY.y);
    return vec3(xyY.z * xz.xy / xyY.y, xyY.z).xzy;
}

float reinhard(const in float color) {
    return color / (1.0 + color);
}

float reinhard2(const in float color, const in float L_white) {
    return (color * (1.0 + color / (L_white * L_white))) / (1.0 + color);
}

void ApplyAutoExposure(inout vec3 rgb, const in sampler2D texExposure) {
	vec3 xyY = xyz_to_xyY(RGB_TO_XYZ * rgb);

	float avgLum = texelFetch(texExposure, ivec2(0.0), 0).r;
    // avgLum = clamp(avgLum, 0.00001, 0.99999);

	float lp = xyY.z / (9.6 * avgLum + 0.0001);

	const float whitePoint = 1.0;
    xyY.z = reinhard2(lp, whitePoint);
	// xyY.z = reinhard(lp);//, whitePoint);

	rgb = XYZ_TO_RGB * xyY_to_xyz(xyY);
}