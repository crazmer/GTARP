CreateThread(function()
    print('[BotRP] Client core initialized.')

    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    print('[BotRP] Network session started.')

    -- Temporary development spawn
    local spawn = vector4(-1037.7, -2737.8, 20.2, 329.0)

    -- Temporary freemode character
    local model = GetHashKey('mp_m_freemode_01')

    RequestModel(model)

    local timeout = 0

    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        print('[BotRP] ERROR: Failed to load player model.')
        return
    end

    print('[BotRP] Player model loaded.')

    SetPlayerModel(PlayerId(), model)

    SetModelAsNoLongerNeeded(model)

    Wait(500)

    local ped = PlayerPedId()

    -- Make absolutely sure the ped is visible
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)

    NetworkSetEntityInvisibleToNetwork(ped, false)

    -- Spawn player
    NetworkResurrectLocalPlayer(
        spawn.x,
        spawn.y,
        spawn.z,
        spawn.w,
        true,
        true,
        false
    )

    Wait(250)

    ped = PlayerPedId()

    SetEntityCoordsNoOffset(
        ped,
        spawn.x,
        spawn.y,
        spawn.z,
        false,
        false,
        false
    )

    SetEntityHeading(ped, spawn.w)

    -- Visibility again after resurrection
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)

    NetworkSetEntityInvisibleToNetwork(ped, false)

    -- Enable player control
    SetPlayerControl(PlayerId(), true, 0)

    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)

    ClearPedTasksImmediately(ped)

    -- Remove loading screen
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    DoScreenFadeIn(1000)

    print('[BotRP] Temporary player spawn completed.')
    print('[BotRP] Ped model: ' .. tostring(GetEntityModel(ped)))
end)