local config = require 'config'
local previewCam
local previewPedEntity
local previewPeds = {}
local previewLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1
local inCharacterLobby = false
local previewGeneration = 0
local previewAnimDict = 'amb@world_human_stand_impatient@male@base'
local previewAnimName = 'base'

local function setGameplayHudVisible(visible)
    DisplayRadar(visible)
    DisplayHud(visible)
    if GetResourceState('qbx_hud') == 'started' then
        SendNUIMessage({ action = 'hudtick', show = visible })
        SendNUIMessage({ action = 'car', show = visible and cache.vehicle ~= nil })
    end
end

local function restorePlayer()
    local ped = cache.ped
    if ped and DoesEntityExist(ped) then
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
    end
    SetFocusEntity(PlayerPedId())
    setGameplayHudVisible(true)
end

local function closeCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    inCharacterLobby = false
end

local function deletePreviewPed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    ClearPedTasksImmediately(ped)
    DeletePed(ped)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
end

-- When replacing a character, keep the existing scripted camera alive. The
-- previous implementation destroyed the camera and restored focus to the
-- hidden player ped before the replacement was ready, which exposed unloaded
-- terrain and made the camera appear to fall under the map for a few seconds.
local function destroyPreview(preserveCamera)
    previewGeneration = previewGeneration + 1

    if previewCam and not preserveCamera then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 250, true, true)
        DestroyCam(previewCam, true)
        previewCam = nil
    elseif previewCam and preserveCamera and DoesCamExist(previewCam) then
        -- Keep the camera exactly where it is while the new model/appearance
        -- is loading. Point it at a stable world position instead of the ped
        -- that is about to be deleted.
        local target = nil
        if previewPedEntity and DoesEntityExist(previewPedEntity) then
            target = GetEntityCoords(previewPedEntity)
        elseif previewLocation and previewLocation.pedCoords then
            target = previewLocation.pedCoords
        end
        if target then
            PointCamAtCoord(previewCam, target.x, target.y, target.z + 0.98)
        end
        SetCamActive(previewCam, true)
        RenderScriptCams(true, false, 0, true, true)
    end

    if previewPedEntity then
        deletePreviewPed(previewPedEntity)
        previewPedEntity = nil
    end
    for ped, _ in pairs(previewPeds) do
        deletePreviewPed(ped)
        previewPeds[ped] = nil
    end

    -- Never return streaming focus to the hidden player while a preview camera
    -- is being preserved. createPreviewPed() will establish the showcase focus
    -- again immediately for the replacement character.
    if not preserveCamera then
        SetFocusEntity(PlayerPedId())
        ClearTimecycleModifier()
    end
end

local function getModelHash(model)
    if type(model) == 'string' then return joaat(model) end
    return model
end

local function requestPreviewAnimation()
    if not lib or not lib.requestAnimDict then return false end
    local ok = pcall(function() lib.requestAnimDict(previewAnimDict) end)
    return ok
end

local function lockPreviewPedToCamera(ped, camX, camY)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    local pedCoords = GetEntityCoords(ped)
    local faceCameraHeading = GetHeadingFromVector_2d(
        camX - pedCoords.x,
        camY - pedCoords.y
    )

    SetEntityHeading(ped, faceCameraHeading)
end

-- Stream the entire preview area, not just the ped spawn point. The previous
-- implementation stopped the scene load before creating the replacement ped,
-- which could leave the camera in unloaded terrain when switching characters.
local function streamShowcaseScene(pedCoords, camCoords)
    local focusX = (pedCoords.x + camCoords.x) * 0.5
    local focusY = (pedCoords.y + camCoords.y) * 0.5
    local focusZ = (pedCoords.z + camCoords.z) * 0.5

    SetFocusPosAndVel(focusX, focusY, focusZ, 0.0, 0.0, 0.0)

    local sceneStarted = false
    if NewLoadSceneStartSphere then
        sceneStarted = NewLoadSceneStartSphere(focusX, focusY, focusZ, 220.0, 0)
    end

    local deadline = GetGameTimer() + 12000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
        RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

        if not sceneStarted or IsNewLoadSceneLoaded() then
            break
        end
        Wait(0)
    end
end

local function waitForPreviewCollision(ped, pedCoords, camCoords)
    local deadline = GetGameTimer() + 8000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
        RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

        local pedLoaded = ped and DoesEntityExist(ped) and HasCollisionLoadedAroundEntity(ped)
        if pedLoaded then
            return true
        end
        Wait(0)
    end
    return false
end

local function createPreviewPed(citizenId)
    -- Keep the existing camera on character switches. Only destroy it when the
    -- entire character preview is being closed (play/create/exit flow).
    destroyPreview(inCharacterLobby and previewCam ~= nil)
    local generation = previewGeneration
    previewLocation = config.locations[1]
    local coords = previewLocation.pedCoords
    local cam = previewLocation.camCoords

    local clothing, model = nil, nil
    if citizenId then
        clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    end
    if generation ~= previewGeneration or not inCharacterLobby then return end

    local camCoords = cam or vec4(
        coords.x - math.sin(math.rad(coords.w)) * 2.8,
        coords.y + math.cos(math.rad(coords.w)) * 2.8,
        coords.z + 1.35,
        0.0
    )

    -- Keep the streaming focus alive throughout character replacement.
    streamShowcaseScene(coords, camCoords)
    if generation ~= previewGeneration or not inCharacterLobby then return end

    local modelHash = getModelHash(model) or `mp_m_freemode_01`
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        modelHash = `mp_m_freemode_01`
    end
    lib.requestModel(modelHash, config.loadingModelsTimeout)
    if generation ~= previewGeneration or not inCharacterLobby then
        SetModelAsNoLongerNeeded(modelHash)
        return
    end

    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

    local ped = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w, false, false)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(modelHash)
        if NewLoadSceneStop then NewLoadSceneStop() end
        return
    end
    previewPeds[ped] = true

    if generation ~= previewGeneration or not inCharacterLobby then
        previewPeds[ped] = nil
        deletePreviewPed(ped)
        SetModelAsNoLongerNeeded(modelHash)
        if NewLoadSceneStop then NewLoadSceneStop() end
        return
    end

    previewPedEntity = ped
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    ClearPedTasksImmediately(ped)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)

    -- Do not release the streaming scene until the replacement ped and camera
    -- area have had a chance to load their collision.
    waitForPreviewCollision(ped, coords, camCoords)

    if generation ~= previewGeneration or not inCharacterLobby then
        previewPeds[ped] = nil
        deletePreviewPed(ped)
        previewPedEntity = nil
        SetModelAsNoLongerNeeded(modelHash)
        if NewLoadSceneStop then NewLoadSceneStop() end
        return
    end

    if clothing and type(clothing) == 'string' and GetResourceState('illenium-appearance') == 'started' then
        pcall(function()
            local appearance = json.decode(clothing)
            if appearance then exports['illenium-appearance']:setPedAppearance(ped, appearance) end
        end)
    end

    lockPreviewPedToCamera(ped, camCoords.x, camCoords.y)
    if requestPreviewAnimation() then
        TaskPlayAnim(ped, previewAnimDict, previewAnimName, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end
    Wait(100)
    lockPreviewPedToCamera(ped, camCoords.x, camCoords.y)
    SetModelAsNoLongerNeeded(modelHash)

    -- Re-request both collision points immediately before activating the camera.
    -- This is especially important after switching from one character to another.
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    Wait(150)

    -- Reuse the preserved camera instead of creating a new camera during a
    -- character switch. This removes the gap where the game camera could fall
    -- back to the hidden player position.
    if previewCam and DoesCamExist(previewCam) then
        SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
        SetCamFov(previewCam, 30.0)
        PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.98, true)
        SetCamActive(previewCam, true)
        RenderScriptCams(true, false, 0, true, true)
    else
        previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
        SetCamFov(previewCam, 30.0)
        PointCamAtEntity(previewCam, ped, 0.0, 0.0, 0.98, true)
        SetCamActive(previewCam, true)
        SetCamUseShallowDofMode(previewCam, true)
        SetCamNearDof(previewCam, 1.0)
        SetCamFarDof(previewCam, 10.0)
        SetCamDofStrength(previewCam, 0.72)
        RenderScriptCams(true, false, 650, true, true)
    end
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 1.0)
    SetCamFarDof(previewCam, 10.0)
    SetCamDofStrength(previewCam, 0.72)
    SetTimecycleModifier('MP_corona_switch')
    SetTimecycleModifierStrength(0.10)

    -- Keep the scene loaded briefly after the camera becomes active. Releasing
    -- it immediately can cause the world behind a newly selected character to
    -- unload and drop the camera through the map.
    Wait(500)
    if generation == previewGeneration and inCharacterLobby and NewLoadSceneStop then
        NewLoadSceneStop()
    end
end

local function sendCharacters()
    local payload = {}
    for i = 1, maxCharacters do
        local character = characters[i]
        if character then
            payload[#payload + 1] = {
                slot = i, citizenid = character.citizenid,
                firstname = character.charinfo.firstname, lastname = character.charinfo.lastname,
                birthdate = character.charinfo.birthdate,
                gender = character.charinfo.gender == 0 and 'Male' or 'Female',
                nationality = character.charinfo.nationality,
                job = character.job and character.job.label or 'Unemployed',
                jobGrade = character.job and character.job.grade and character.job.grade.name or '',
                cash = character.money and character.money.cash or 0,
                bank = character.money and character.money.bank or 0,
                phone = character.charinfo.phone or ''
            }
        else
            payload[#payload + 1] = { slot = i, empty = true }
        end
    end
    SendNUIMessage({ action = 'characters', characters = payload, selected = selectedIndex })
end

local function openCharacterScreen()
    if inCharacterLobby then return end
    inCharacterLobby = true
    setGameplayHudVisible(false)
    local playerPed = cache.ped
    if playerPed and DoesEntityExist(playerPed) then
        FreezeEntityPosition(playerPed, true)
        SetEntityCollision(playerPed, false, false)
        SetEntityVisible(playerPed, false, false)
    end
    characters, maxCharacters = lib.callback.await('qbx_core:server:getCharacters')
    characters = characters or {}
    maxCharacters = maxCharacters or #characters
    selectedIndex = 1
    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end
    local first = characters[1]
    createPreviewPed(first and first.citizenid)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(700)
    SetNuiFocus(true, true)
    sendCharacters()
    SendNUIMessage({ action = 'open' })
end

RegisterNUICallback('select', function(data, cb)
    local index = tonumber(data.slot) or 1
    if index < 1 or index > maxCharacters then cb({ ok = false }); return end
    selectedIndex = index
    local character = characters[index]
    if character then createPreviewPed(character.citizenid) end
    cb({ ok = true })
    sendCharacters()
end)

RegisterNUICallback('play', function(data, cb)
    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character then cb({ ok = false, error = 'Select a character first.' }); return end
    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    destroyPreview()
    local ok, err = pcall(function() lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid) end)
    if not ok then
        inCharacterLobby = false
        restorePlayer()
        DoScreenFadeIn(500)
        cb({ ok = false, error = tostring(err) })
        return
    end
    if GetResourceState('qbx_apartments'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', character.citizenid)
    elseif GetResourceState('qbx_spawn'):find('start') then
        TriggerEvent('qb-spawn:client:setupSpawns', character.citizenid)
        TriggerEvent('qb-spawn:client:openUI', true)
    else
        local pos = character.position
        if pos then
            SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, false, false, false, false)
            SetEntityHeading(cache.ped, pos.w or 0.0)
        end
        restorePlayer()
        DoScreenFadeIn(700)
    end
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    local slot = tonumber(data.slot) or 1
    if slot < 1 or slot > maxCharacters or characters[slot] then
        cb({ ok = false, error = 'That character slot is unavailable.' })
        return
    end
    local gender = data.gender == 'Female' and 1 or 0
    local result = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = tostring(data.firstname or ''), lastname = tostring(data.lastname or ''),
        nationality = tostring(data.nationality or ''), gender = gender,
        birthdate = tostring(data.birthdate or ''), cid = slot
    })
    if not result then
        cb({ ok = false, error = 'Character creation failed. Check the information and try again.' })
        return
    end
    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    destroyPreview()
    restorePlayer()
    TriggerEvent('apartments:client:setupSpawnUI', result)
    cb({ ok = true })
end)

RegisterNUICallback('close', function(_, cb) cb({ ok = false }) end)
RegisterNetEvent('botrp_character:client:open', openCharacterScreen)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    Wait(1500)
    openCharacterScreen()
end)

CreateThread(function()
    while true do
        if inCharacterLobby then
            setGameplayHudVisible(false)
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    local phase = 0.0
    while true do
        if inCharacterLobby and previewCam and DoesCamExist(previewCam) then
            phase = phase + 0.008
            local cam = previewLocation and previewLocation.camCoords
            if cam then
                local bob = math.sin(phase) * 0.018
                SetCamCoord(previewCam, cam.x, cam.y, cam.z + bob)
                if previewPedEntity and DoesEntityExist(previewPedEntity) then
                    PointCamAtEntity(previewCam, previewPedEntity, 0.0, 0.0, 0.98, true)
                    lockPreviewPedToCamera(previewPedEntity, cam.x, cam.y)
                end
            end
            Wait(0)
        else
            phase = 0.0
            Wait(250)
        end
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    Wait(500)
    openCharacterScreen()
end)

CreateThread(function() print('[BotRP] character v0.2.2 started') end)
