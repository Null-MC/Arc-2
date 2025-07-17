vec3 renderSky(const in vec3 localPos, const in vec3 viewLocalDir, bool isReflection) {
    vec3 starViewDir = getStarViewDir(viewLocalDir);
    vec3 skyLight = STAR_LUMINANCE * GetStarLight(starViewDir);

    #ifdef WORLD_OVERWORLD
        vec3 skyPos = getSkyPosition(localPos);
        bool intersectsPlanet = rayIntersectSphere(skyPos, viewLocalDir, groundRadiusMM) >= 0.0;

        if (!intersectsPlanet) {
            float sunF = sun(viewLocalDir, Scene_LocalSunDir);
            if (sunF > 0.0) skyLight = sunF * SUN_LUMINANCE * Scene_SunColor;

            vec3 moonLocalPos = moon_distanceKm * -Scene_LocalSunDir + localPos;
            float moonHitDist = rayIntersectSphere(moonLocalPos, -viewLocalDir, moon_radiusKm);

            if (moonHitDist > 0.0) {
                skyLight = renderMoon(viewLocalDir, moonLocalPos, moonHitDist, isReflection);
            }
        }
    #endif

    #ifdef WORLD_END
        vec3 endSunPos = endSun_distanceKm * -Scene_LocalSunDir + localPos;
        float endSunHitDist = rayIntersectSphere(endSunPos, -viewLocalDir, endSun_radiusKm);

        if (endSunHitDist > 0.0) {
            skyLight = renderEndSun(viewLocalDir, endSunPos, endSunHitDist);
        }

        float worldTime = ap.time.elapsed;//mod(ap.world.time / 24000.0, 1.0);
        vec3 endEarthLocalDir = vec3(0.0, 0.0, 1.0);
        endEarthLocalDir = rotateY(endEarth_orbitSpeed * worldTime * TAU) * endEarthLocalDir;
        endEarthLocalDir = rotateX(0.4) * endEarthLocalDir;
        endEarthLocalDir = normalize(endEarthLocalDir);

        vec3 endEarthPos = endEarth_distanceKm * endEarthLocalDir + localPos;
        float endEarthHitDist = rayIntersectSphere(endEarthPos, -viewLocalDir, endEarth_radiusKm);

        if (endEarthHitDist > 0.0) {
            skyLight = renderEndEarth(viewLocalDir, endEarthPos, endEarthHitDist);
        }
    #endif

    #ifdef WORLD_OVERWORLD
        if (intersectsPlanet) skyLight = vec3(0.0);
        else skyLight *= getValFromTLUT(texSkyTransmit, skyPos, viewLocalDir);

        skyLight += getValFromSkyLUT(texSkyView, skyPos, viewLocalDir, Scene_LocalSunDir);
    #endif

    return skyLight;
}
