return {
    loadingModelsTimeout = 30000,
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    -- Stable outdoor preview location. Keeping this in the normal world avoids
    -- interior IPL/streaming issues that can leave the camera looking at empty sky.
    locations = {
        {
            pedCoords = vec4(215.76, -810.12, 30.73, 338.0),
            camCoords = vec4(218.15, -807.25, 31.55, 158.0)
        }
    }
}
