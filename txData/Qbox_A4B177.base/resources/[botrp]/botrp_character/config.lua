return {
    loadingModelsTimeout = 30000,
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    -- Outdoor showcase scene for the character lobby.
    -- Keep the preview in the normal world to avoid interior IPL/streaming issues.
    locations = {
        {
            -- Face the preview ped toward the camera instead of showing its back.
            pedCoords = vec4(-1594.64, -1141.70, 14.29, 132.7),
            -- Front three-quarter camera: head/chest framing with the scene visible behind.
            camCoords = vec4(-1591.55, -1144.55, 15.85, 0.0)
        }
    }
}
