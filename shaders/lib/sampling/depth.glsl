float linearizeDepth(const in float clipDepth, const in float zNear, const in float zFar) {
    float ndcDepth = clipDepth * 2.0 - 1.0;
    return 2.0 * zNear * zFar / (zFar + zNear - ndcDepth * (zFar - zNear));
}

float delinearizeDepth(const in float linearDepth, const in float zNear, const in float zFar) {
    float ndcDepth = (zFar + zNear - 2.0 * zNear * zFar / linearDepth) / (zFar - zNear);
    return (ndcDepth + 1.0) / 2.0;
}
