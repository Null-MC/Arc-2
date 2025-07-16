void dda_init(out vec3 stepSizes, out vec3 nextDist, const in vec3 currPos, const in vec3 localDir) {
    vec3 stepDir = sign(localDir);
    stepSizes = 1.0 / abs(localDir);

    nextDist = stepDir * 0.5 + 0.5;
    nextDist = (nextDist - fract(currPos)) / localDir;
}

vec3 dda_step(out vec3 stepAxis, inout vec3 nextDist, const in vec3 stepSizes, const in vec3 localDir) {
    float closestDist = minOf(nextDist);
    stepAxis = vec3(lessThanEqual(nextDist, vec3(closestDist)));

    nextDist -= closestDist;
    nextDist = fma(stepSizes, stepAxis, nextDist);

    return localDir * closestDist;
}
