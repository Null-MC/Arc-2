const float PI = 3.14159265358;
const float TAU = PI * 2.0;
const float EPSILON = 1e-6;

const float IOR_AIR   = 1.00;
const float IOR_WATER = 1.33;

const vec3 luma_factor = vec3(0.2126, 0.7152, 0.0722);


float maxOf(const in vec2 vec) {return max(vec[0], vec[1]);}
float maxOf(const in vec3 vec) {return max(max(vec[0], vec[1]), vec[2]);}

int sumOf(ivec3 vec) {return vec.x + vec.y + vec.z;}

vec3 LinearToRgb(const in vec3 color) {return pow(color, vec3(1.0 / 2.2));}

vec3 RgbToLinear(const in vec3 color) {return pow(color, vec3(2.2));}

float luminance(const in vec3 color) {
   return dot(color, luma_factor);
}

float saturate(const in float x) {return clamp(x, 0.0, 1.0);}

vec3 unproject(const in vec4 pos) {
    return pos.xyz / pos.w;
}

vec3 unproject(const in mat4 matProj, const in vec3 pos) {
    return unproject(matProj * vec4(pos, 1.0));
}

vec3 mul3(const in mat4 matrix, const in vec3 vector) {
	return mat3(matrix) * vector + matrix[3].xyz;
}
