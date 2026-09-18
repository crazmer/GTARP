local config = require 'config.client'
local spawns
local previewCam
local scaleform
local buttonsScaleform
local currentButtonId = 1
local previousButtonId = 1

local function setupCamera()
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', -24.77, -590.35, 90.8, -2.0, 0.0, 160.0, 45.0, false, 2)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 1, true, true)
end

local function stopCamera()
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, true)
    RenderScriptCams(false, false, 1, true, true)

    BeginScaleformMovieMethod(scaleform, 'CLEANUP')
    EndScaleformMovieMethod()
end

local function hardenGameplayPed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 255, false)
    SetEntityCollision(ped, false, false)
    SetEntityCompletelyDisableCollision(ped, false)
    SetEntityLoadCollisionFlag(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetEntityDynamic(ped, false)
    FreezeEntityPosition(ped, true)
    return ped
end

local function restoreGameplayPed()
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    SetEntityCompletelyDisableCollision(ped, false)
    SetEntityLoadCollisionFlag(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetEntityDynamic(ped, true)
    ActivatePhysics(ped)
    SetPlayerControl(PlayerId(), true, 0)
    return ped
end

local function managePlayer()
    -- Keep the real gameplay ped frozen while the spawn selector/camera is active.
    -- Do not move it to the remote showcase location.
    local ped = hardenGameplayPed()
    DisplayRadar(false)

    -- qbx_spawn is a scripted camera UI; keep the game visible while the player
    -- chooses a destination. The previous pass left the fade-out active here,
    -- which produced the black screen reported after character selection.
    SetTimeout(500, function()
        DoScreenFadeIn(1000)
    end)

    return ped
end

local function spawnAtDestination(spawnData)
    if not spawnData or not spawnData.coords then return false end

    local coords = spawnData.coords
    local heading = coords.w or 0.0
    local playerId = PlayerId()
    local ped = PlayerPedId()

    -- Fully stream the destination before moving the player. FiveM's spawnmanager
    -- requests collision, but the full load-scene cycle is what prevents a remote
    -- destination from appearing as an empty grey void.
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

    if NewLoadSceneStart then
        pcall(function()
            NewLoadSceneStart(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 60.0, 0)
        end)
    end

    local sceneDeadline = GetGameTimer() + 15000
    while GetGameTimer() < sceneDeadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

        if NetworkUpdateLoadScene then
            NetworkUpdateLoadScene()
        end

        if IsNewLoadSceneLoaded and IsNewLoadSceneLoaded() then
            break
        end

        Wait(0)
    end

    -- Match the normal Qbox/FiveM spawn lifecycle.
    SetPlayerControl(playerId, false, 0)
    SetPlayerInvincible(playerId, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityCompletelyDisableCollision(ped, false)
    SetEntityLoadCollisionFlag(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetEntityDynamic(ped, false)
    FreezeEntityPosition(ped, true)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, true, false)

    ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    SetEntityCompletelyDisableCollision(ped, false)
    SetEntityLoadCollisionFlag(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetEntityDynamic(ped, false)
    FreezeEntityPosition(ped, true)

    local collisionDeadline = GetGameTimer() + 12000
    local collisionReady = false

    while GetGameTimer() < collisionDeadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

        if NetworkUpdateLoadScene then
            NetworkUpdateLoadScene()
        end

        if HasCollisionLoadedAroundEntity(ped) then
            collisionReady = true
            break
        end

        Wait(0)
    end

    if not collisionReady then
        print(('[qbx_spawn] collision timeout at %.2f %.2f %.2f'):format(coords.x, coords.y, coords.z))
        if NewLoadSceneStop then NewLoadSceneStop() end
        ClearFocus()
        SetPlayerInvincible(playerId, false)
        return false
    end

    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, heading)
    ClearPedTasksImmediately(ped)
    RemoveAllPedWeapons(ped)
    ClearPlayerWantedLevel(playerId)

    -- Keep collision requests active through several physics frames before release.
    for _ = 1, 120 do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCollision(ped, true, true)
        SetEntityCompletelyDisableCollision(ped, false)
        SetEntityLoadCollisionFlag(ped, true, true)
        FreezeEntityPosition(ped, true)
        Wait(0)
    end

    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    SetEntityHasGravity(ped, true)
    SetEntityDynamic(ped, true)
    ActivatePhysics(ped)
    SetPlayerInvincible(playerId, false)

    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()

    return true
end

local function createSpawnArea()
    for i = 1, #spawns, 1 do
        local spawn = spawns[i]
        BeginScaleformMovieMethod(scaleform, 'ADD_AREA')
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamFloat(spawn.coords.x)
        ScaleformMovieMethodAddParamFloat(spawn.coords.y)
        ScaleformMovieMethodAddParamFloat(500.0)
        ScaleformMovieMethodAddParamInt(255)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(100)
        EndScaleformMovieMethod()
    end
end

local function setupInstructionalButton(index, control, text)
    BeginScaleformMovieMethod(buttonsScaleform, 'SET_DATA_SLOT')

    ScaleformMovieMethodAddParamInt(index)

    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, control, true))

    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()

    EndScaleformMovieMethod()
end

local function setupInstructionalScaleform()
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 0, 0)

    BeginScaleformMovieMethod(buttonsScaleform, 'CLEAR_ALL')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(buttonsScaleform, 'SET_CLEAR_SPACE')
    ScaleformMovieMethodAddParamInt(200)
    EndScaleformMovieMethod()

    setupInstructionalButton(0, 191, 'Submit')
    setupInstructionalButton(1, 187, 'Down')
    setupInstructionalButton(2, 188, 'Up')

    BeginScaleformMovieMethod(buttonsScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    EndScaleformMovieMethod()
end

local function setupMap()
    scaleform = lib.requestScaleformMovie('HEISTMAP_MP', 5000) or 0
    buttonsScaleform = lib.requestScaleformMovie('INSTRUCTIONAL_BUTTONS', 5000) or 0
    CreateThread(function()
        setupInstructionalScaleform()
        createSpawnArea()
        while DoesCamExist(previewCam) do
            DrawScaleformMovie_3d(scaleform, -24.86, -593.38, 91.8, -180.0, -180.0, -20.0, 0.0, 2.0, 0.0, 3.815, 2.27, 1.0, 2)

            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(9)

            DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)
            Wait(0)
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
        SetScaleformMovieAsNoLongerNeeded(buttonsScaleform)
    end)
end

local function scaleformDetails(index)
    local spawn = spawns[index]
    local arrowStart = {
        vec2(-3150.25, -1427.83),
        vec2(4173.08, 1338.72),
        vec2(-2390.23, 6262.24)
    }

    BeginScaleformMovieMethod(scaleform, 'ADD_HIGHLIGHT')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(500.0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'COLOUR_AREA')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'ADD_TEXT')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamTextureNameString(spawn.label)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y - 500)
    ScaleformMovieMethodAddParamFloat(25 - math.random(0, 50))
    ScaleformMovieMethodAddParamInt(24)
    ScaleformMovieMethodAddParamInt(100)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamBool(true)
    EndScaleformMovieMethod()

    local randomCoords = arrowStart[math.random(#arrowStart)]

    BeginScaleformMovieMethod(scaleform, 'ADD_ARROW')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamFloat(randomCoords.x)
    ScaleformMovieMethodAddParamFloat(randomCoords.y)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(math.random(30, 80))
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'COLOUR_ARROW')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()
end

local function updateScaleform()
    if previousButtonId == currentButtonId then return end

    for i = 1, #spawns, 1 do
        BeginScaleformMovieMethod(scaleform, 'REMOVE_HIGHLIGHT')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'REMOVE_TEXT')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'REMOVE_ARROW')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'COLOUR_AREA')
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamInt(255)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(100)
        EndScaleformMovieMethod()
    end

    scaleformDetails(currentButtonId)
end

local function inputHandler()
    while DoesCamExist(previewCam) do
        if IsControlJustReleased(0, 188) then
            previousButtonId = currentButtonId
            currentButtonId -= 1

            if currentButtonId < 1 then
                currentButtonId = #spawns
            end

            updateScaleform()
        elseif IsControlJustReleased(0, 187) then
            previousButtonId = currentButtonId
            currentButtonId += 1

            if currentButtonId > #spawns then
                currentButtonId = 1
            end

            updateScaleform()
        elseif IsControlJustReleased(0, 191) then
            local spawnData = spawns[currentButtonId]
            if not spawnData or not spawnData.coords then
                print('[qbx_spawn] selected spawn has no coordinates')
            else
                DoScreenFadeOut(500)
                while not IsScreenFadedOut() do
                    Wait(0)
                end

                -- Let spawnmanager establish the final world position first.
                -- Qbox's player-loaded events are fired only after a successful
                -- spawn so other resources don't initialize against an unloaded
                -- or invalid player position.
                local spawned = false

                if spawnData.propertyId then
                    TriggerServerEvent('qbx_properties:server:enterProperty', {
                        id = spawnData.propertyId,
                        isSpawn = true
                    })
                    Wait(1200)
                    spawned = true
                else
                    spawned = spawnAtDestination(spawnData)
                end

                if spawned then
                    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
                    TriggerEvent('QBCore:Client:OnPlayerLoaded')
                    local ped = restoreGameplayPed()
                    FreezeEntityPosition(ped, true)
                    Wait(750)
                    FreezeEntityPosition(ped, false)
                    DisplayRadar(true)
                    DoScreenFadeIn(1000)
                    break
                end

                print('[qbx_spawn] spawn failed; leaving player frozen rather than dropping them into an unloaded world')
                local ped = restoreGameplayPed()
                FreezeEntityPosition(ped, true)
                DisplayRadar(false)
                DoScreenFadeIn(500)
            end
        end

        Wait(0)
    end

    stopCamera()
end

RegisterNetEvent('qb-spawn:client:setupSpawns', function()
    spawns = {}

    local lastCoords, lastPropertyId = lib.callback.await('qbx_spawn:server:getLastLocation')
    spawns[#spawns + 1] = {
        label = locale('last_location'),
        coords = lastCoords,
        propertyId = lastPropertyId
    }

    for i = 1, #config.spawns do
        spawns[#spawns + 1] = config.spawns[i]
    end

    local properties = lib.callback.await('qbx_spawn:server:getProperties')
    for i = 1, #properties do
        spawns[#spawns + 1] = properties[i]
    end

    Wait(400)

    managePlayer()
    setupCamera()
    setupMap()

    Wait(400)

    scaleformDetails(currentButtonId)
    inputHandler()
end)