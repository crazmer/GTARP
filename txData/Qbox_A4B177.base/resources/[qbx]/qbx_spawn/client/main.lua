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

local function streamSpawnArea(coords)
    if not coords then return false end

    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

    if NewLoadSceneStartSphere then
        pcall(function()
            NewLoadSceneStartSphere(coords.x, coords.y, coords.z, 260.0, 0)
        end)
    end

    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

        local loaded = (not IsNewLoadSceneActive or not IsNewLoadSceneActive()) or IsNewLoadSceneLoaded()
        if loaded then
            return true
        end
        Wait(0)
    end

    return false
end

local function resolveGround(coords)
    if not coords then return end

    -- Keep asking for the exact destination tile until GTA reports an actual
    -- ground surface. This is stronger than HasCollisionLoadedAroundEntity(),
    -- which can succeed before the player-facing floor is available.
    local deadline = GetGameTimer() + 8000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)

        local ok, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 120.0, false)
        if ok and groundZ and groundZ > -100.0 then
            return groundZ
        end
        Wait(0)
    end
end

local function waitForSpawnCollision(coords)
    if not coords then return false end

    local groundZ = resolveGround(coords)
    if groundZ then return true end

    local deadline = GetGameTimer() + 4000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)
        if HasCollisionLoadedAroundEntity(cache.ped) then
            return true
        end
        Wait(0)
    end

    return false
end

local function hardenGameplayPed()
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
    SetPedCanRagdoll(ped, true)
    return ped
end

local function teleportToSpawn(spawnData)
    local coords = spawnData.coords
    if not coords then return false end

    streamSpawnArea(coords)

    local ped = hardenGameplayPed()
    FreezeEntityPosition(ped, true)

    local groundZ = resolveGround(coords)
    local targetZ = groundZ or coords.z
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, targetZ + 0.9, false, false, false)
    SetEntityHeading(ped, coords.w or 0.0)

    -- Reassert collision and wait through several physics frames before release.
    local collisionReady = waitForSpawnCollision(vec4(coords.x, coords.y, targetZ, coords.w or 0.0))
    for _ = 1, 90 do
        RequestCollisionAtCoord(coords.x, coords.y, targetZ)
        RequestAdditionalCollisionAtCoord(coords.x, coords.y, targetZ)
        SetEntityCollision(ped, true, true)
        SetEntityCompletelyDisableCollision(ped, false)
        FreezeEntityPosition(ped, true)
        Wait(0)
    end

    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()
    return collisionReady
end

local function recoverFromBadSpawn(spawnData)
    if not spawnData or spawnData.propertyId or not spawnData.coords then return end

    local expected = spawnData.coords
    CreateThread(function()
        local deadline = GetGameTimer() + 15000
        local graceUntil = GetGameTimer() + 2500
        local fallingSince

        while GetGameTimer() < deadline do
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local velocity = GetEntityVelocity(ped)
            local fallingFast = velocity and velocity.z < -1.5
            local airborne = IsEntityInAir(ped)

            RequestCollisionAtCoord(expected.x, expected.y, expected.z)
            RequestAdditionalCollisionAtCoord(expected.x, expected.y, expected.z)
            SetEntityCollision(ped, true, true)
            SetEntityCompletelyDisableCollision(ped, false)
            SetEntityLoadCollisionFlag(ped, true, true)

            if GetGameTimer() > graceUntil and (pos.z < expected.z - 8.0 or fallingFast or airborne) then
                fallingSince = fallingSince or GetGameTimer()

                if fallingFast or GetGameTimer() - fallingSince > 750 then
                    local groundZ = resolveGround(expected)
                    if groundZ then
                        FreezeEntityPosition(ped, true)
                        SetEntityVisible(ped, true, false)
                        SetEntityAlpha(ped, 255, false)
                        ResetEntityAlpha(ped)
                        SetEntityCollision(ped, true, true)
                        SetEntityCompletelyDisableCollision(ped, false)
                        SetEntityLoadCollisionFlag(ped, true, true)
                        SetEntityHasGravity(ped, true)
                        SetEntityDynamic(ped, true)
                        SetEntityCoordsNoOffset(ped, expected.x, expected.y, groundZ + 0.9, false, false, false)
                        SetEntityHeading(ped, expected.w or 0.0)

                        for _ = 1, 90 do
                            RequestCollisionAtCoord(expected.x, expected.y, groundZ)
                            RequestAdditionalCollisionAtCoord(expected.x, expected.y, groundZ)
                            SetEntityCollision(ped, true, true)
                            SetEntityCompletelyDisableCollision(ped, false)
                            SetEntityLoadCollisionFlag(ped, true, true)
                            Wait(0)
                        end

                        ActivatePhysics(ped)
                        FreezeEntityPosition(ped, false)
                    end
                    break
                end
            else
                fallingSince = nil
            end

            Wait(50)
        end
    end)
end

local function managePlayer()
    local staging = vec4(-21.58, -583.76, 86.31, 0.0)
    local ped = hardenGameplayPed()
    FreezeEntityPosition(ped, true)
    streamSpawnArea(staging)
    local groundZ = resolveGround(staging) or staging.z
    SetEntityCoordsNoOffset(ped, staging.x, staging.y, groundZ + 0.05, false, false, false)
    SetEntityHeading(ped, staging.w)
    waitForSpawnCollision(vec4(staging.x, staging.y, groundZ, staging.w))
    DisplayRadar(false)

    SetTimeout(500, function()
        DoScreenFadeIn(5000)
    end)
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
            DoScreenFadeOut(1000)

            while not IsScreenFadedOut() do
                Wait(0)
            end

            local spawnData = spawns[currentButtonId]

            -- Never release the gameplay ped before its destination collision is loaded.
            SetEntityCollision(cache.ped, true, true)
            SetEntityCompletelyDisableCollision(cache.ped, false)
            SetEntityVisible(cache.ped, true, false)
            SetEntityAlpha(cache.ped, 255, false)
            ResetEntityAlpha(cache.ped)
            FreezeEntityPosition(cache.ped, true)

            if spawnData.propertyId then
                TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
                TriggerEvent('QBCore:Client:OnPlayerLoaded')
                TriggerServerEvent('qbx_properties:server:enterProperty', { id = spawnData.propertyId, isSpawn = true })
                Wait(1200)
            else
                local spawnReady = teleportToSpawn(spawnData)
                if not spawnReady then
                    print('[qbx_spawn] collision did not fully report ready at selected spawn; keeping recovery guard active')
                end
                TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
                TriggerEvent('QBCore:Client:OnPlayerLoaded')
                recoverFromBadSpawn(spawnData)
            end

            Wait(750)
            hardenGameplayPed()
            FreezeEntityPosition(cache.ped, false)
            DisplayRadar(true)
            DoScreenFadeIn(1000)

            break
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