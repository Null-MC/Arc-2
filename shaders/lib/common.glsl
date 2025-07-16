const float PI = 3.14159265358;
const float TAU = PI * 2.0;
const float EPSILON = 1e-6;

const float IOR_AIR   = 1.00;
const float IOR_WATER = 1.33;

const float GoldenAngle = PI * (3.0 - sqrt(5.0));
const float PHI = (1.0 + sqrt(5.0)) / 2.0;

const vec3 luma_factor = vec3(0.2126, 0.7152, 0.0722);


float maxOf(const in vec2 vec) {return max(vec[0], vec[1]);}
float maxOf(const in vec3 vec) {return max(max(vec[0], vec[1]), vec[2]);}

float minOf(const in vec2 vec) {return min(vec[0], vec[1]);}
float minOf(const in vec3 vec) {return min(min(vec[0], vec[1]), vec[2]);}

int sumOf(ivec3 vec) {return vec.x + vec.y + vec.z;}
float sumOf(vec3 vec) {return vec.x + vec.y + vec.z;}

//vec3 LinearToRgb(const in vec3 color) {return pow(color, vec3(1.0 / 2.2));}

//vec3 RgbToLinear(const in vec3 color) {return pow(color, vec3(2.2));}

vec3 LinearToRgb(const in vec3 color) {
    vec3 is_high = step(0.00313066844250063, color);
    vec3 higher = 1.055 * pow(color, vec3(1.0/2.4)) - 0.055;
    vec3 lower = color * 12.92;

    return mix(lower, higher, is_high);
}

vec3 RgbToLinear(const in vec3 color) {
    vec3 is_high = step(0.0404482362771082, color);
    vec3 higher = pow((color + 0.055) / 1.055, vec3(2.4));
    vec3 lower = color / 12.92;

    return mix(lower, higher, is_high);
}

float lengthSq(const in vec3 vec) {return dot(vec, vec);}

//float log(const in float base, const in float value) {
//    return log2(value) / log2(base);
//}

const float _base6_inv = 1.0  / log2(6);
float log6(const in float value) {
    return log2(value) * _base6_inv;
}

vec3 log6(const in vec3 value) {
    return log2(value) * _base6_inv;
}

float luminance(const in vec3 color) {
   return dot(color, luma_factor);
}

float pow4(const in float x) {
    float x2 = x*x;
    return x2*x2;
}

float pow5(const in float x) {
    float x2 = x*x;
    return x2*x2*x;
}

float saturate(const in float x) {return clamp(x, 0.0, 1.0);}
vec2 saturate(const in vec2 x) {return clamp(x, 0.0, 1.0);}
vec3 saturate(const in vec3 x) {return clamp(x, 0.0, 1.0);}

vec3 mul3(const in mat4 matrix, const in vec3 vector) {
    return mat3(matrix) * vector + matrix[3].xyz;
}

vec3 unproject(const in vec4 pos) {
    return pos.xyz / pos.w;
}

vec3 unproject(const in mat4 matProj, const in vec3 pos) {
    return unproject(matProj * vec4(pos, 1.0));
}

float unmix(const in float valueMin, const in float valueMax, const in float value) {
    return (value - valueMin) / (valueMax - valueMin);
}

vec2 unmix(const in float valueMin, const in float valueMax, const in vec2 value) {
    return (value - valueMin) / (valueMax - valueMin);
}

vec2 unmix(const in vec2 valueMin, const in vec2 valueMax, const in vec2 value) {
    return (value - valueMin) / (valueMax - valueMin);
}


#define _pow2(x) ((x)*(x))
#define _pow3(x) ((x)*(x)*(x))

#define _RgbToLinear(color) (pow((color), vec3(2.2)))
