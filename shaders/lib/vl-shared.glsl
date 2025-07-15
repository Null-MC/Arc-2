#ifdef SKY_CLOUDS_ENABLED
    void vl_sampleClouds(const in vec3 localViewDir, out vec3 cloud_localPos, out float cloudDensity, out float cloud_shadowSun, out float cloud_shadowMoon) {
        cloudDensity = 0.0;
        cloud_shadowSun = 1.0;
        cloud_shadowMoon = 1.0;

        float cloudShadowF = smoothstep(0.1, 0.2, Scene_LocalLightDir.y);

        if (abs(localViewDir.y) > 0.0 && sign(cloudHeight-ap.camera.pos.y) == sign(localViewDir.y)) {
            float cloudDist = abs((cloudHeight-ap.camera.pos.y) / localViewDir.y);

            cloud_localPos = cloudDist * localViewDir;

            vec3 cloudWorldPos = cloud_localPos + ap.camera.pos;

            if (cloudDist < 8000.0) {
                cloudDensity = SampleCloudDensity(cloudWorldPos);

                float dither = InterleavedGradientNoise(gl_FragCoord.xy);

                float shadowStepLen = 0.8;
                float density_sun = 0.0;
                float density_moon = 0.0;

                for (int i = 1; i <= 8; i++) {
                    vec3 step = (i+dither)*shadowStepLen*Scene_LocalSunDir;

                    density_sun  += SampleCloudDensity(cloudWorldPos + step) * shadowStepLen;
                    density_moon += SampleCloudDensity(cloudWorldPos - step) * shadowStepLen;

                    shadowStepLen *= 1.5;
                }

                cloudDensity *= 1.0 - smoothstep(4000.0, 8000.0, cloudDist);

                float extinction = mieScatteringF + mieAbsorptionF;

                cloud_shadowSun  *= exp(-extinction * density_sun);
                cloud_shadowMoon *= exp(-extinction * density_moon);
            }
        }
    }

    void vl_renderClouds(inout vec3 transmittance, inout vec3 scattering, const in float miePhase_sun, const in float miePhase_moon, const in vec3 cloud_localPos, const in float cloudDensity, const in float cloud_shadowSun, const in float cloud_shadowMoon) {
        vec3 sunTransmit, moonTransmit;
        GetSkyLightTransmission(cloud_localPos, sunTransmit, moonTransmit);

        float skyLightF = smoothstep(0.0, 0.08, Scene_LocalLightDir.y);
        vec3 sunSkyLight = skyLightF * SUN_LUX * sunTransmit * Scene_SunColor * cloud_shadowSun;
        vec3 moonSkyLight = skyLightF * MOON_LUX * moonTransmit * cloud_shadowMoon;

        vec3 skyPos = getSkyPosition(cloud_localPos);

        float mieDensity = cloudDensity + EPSILON;
        float mieScattering = mieScatteringF * mieDensity;
        float mieAbsorption = mieAbsorptionF * mieDensity;
        vec3 extinction = vec3(mieScattering + mieAbsorption);

        const float stepDist = 10.0;
        vec3 sampleTransmittance = exp(-extinction * stepDist);

        vec3 psiMS = getValFromMultiScattLUT(texSkyMultiScatter, skyPos, Scene_LocalSunDir);
        vec3 ambient = psiMS * Scene_SkyBrightnessSmooth + VL_MinLight;

        vec3 mieSkyLight = miePhase_sun * sunSkyLight + miePhase_moon * moonSkyLight;
        vec3 mieInScattering = mieScattering * (mieSkyLight + ambient);
        vec3 inScattering = mieInScattering;//rayleighInScattering; // + mieInScattering

        vec3 scatteringIntegral = (inScattering - inScattering * sampleTransmittance) / extinction;

        scattering += scatteringIntegral * transmittance;
        transmittance *= sampleTransmittance;
    }
#endif
