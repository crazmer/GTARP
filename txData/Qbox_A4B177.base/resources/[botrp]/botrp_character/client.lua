local config = require 'config'
local previewCam
local previewPedEntity
local previewPeds = {}
local previewLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1
local inCharacterLobby = false
local lobbyActionBusy = false
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

local function destroyPreview(preserveCamera)
    previewGeneration = previewGeneration + 1

    if previewCam and not preserveCamera then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 250, true, true)
        DestroyCam(previewCam, true)
        previewCam = nil
    elseif previewCam and preserveCamera and DoesCamExist(previewCam) then
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
    local faceCameraHeading = GetHeadingFromVector_2d(camX - pedCoords.x, camY - pedCoords.y)
    SetEntityHeading(ped, faceCameraHeading)
end

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
        if not sceneStarted or IsNewLoadSceneLoaded() then break end
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
        if ped and DoesEntityExist(ped) and HasCollisionLoadedAroundEntity(ped) then return true end
        Wait(0)
    end
    return false
end

local function createPreviewPed(citizenId)
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
    local camCoords = cam or vec4(coords.x - math.sin(math.rad(coords.w)) * 2.8, coords.y + math.cos(math.rad(coords.w)) * 2.8, coords.z + 1.35, 0.0)
    streamShowcaseScene(coords, camCoords)
    if generation ~= previewGeneration or not inCharacterLobby then return end
    local modelHash = getModelHash(model) or `mp_m_freemode_01`
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then modelHash = `mp_m_freemode_01` end
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
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    RequestAdditionalCollisionAtCoord(coords.x, coords.y, coords.z)
    RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    Wait(150)
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
    Wait(500)
    if generation == previewGeneration and inCharacterLobby and NewLoadSceneStop then NewLoadSceneStop() end
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

local function refreshCharacters()
    characters, maxCharacters = lib.callback.await('qbx_core:server:getCharacters')
    characters = characters or {}
    maxCharacters = maxCharacters or #characters
    if maxCharacters < 1 then maxCharacters = 1 end
    if selectedIndex > maxCharacters then selectedIndex = maxCharacters end
    sendCharacters()
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
    if lobbyActionBusy then cb({ ok = false, error = 'Please wait for the current character preview.' }); return end

    selectedIndex = index
    local character = characters[index]
    if not character then
        sendCharacters()
        cb({ ok = true })
        return
    end

    lobbyActionBusy = true
    createPreviewPed(character.citizenid)
    lobbyActionBusy = false
    sendCharacters()
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(data, cb)
    if lobbyActionBusy then
        cb({ ok = false, error = 'Please wait for the current character action.' })
        return
    end

    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character or not character.citizenid then
        cb({ ok = false, error = 'Character not found.' })
        return
    end

    lobbyActionBusy = true
    local citizenId = character.citizenid
    local deleted = lib.callback.await('qbx_core:server:deleteCharacter', false, citizenId)
    if not deleted then
        refreshCharacters()
        lobbyActionBusy = false
        cb({ ok = false, error = 'Character could not be deleted. It may already have been removed.' })
        return
    end

    refreshCharacters()
    if selectedIndex > maxCharacters then selectedIndex = math.max(1, maxCharacters) end
    local replacement = characters[selectedIndex]
    if replacement then
        createPreviewPed(replacement.citizenid)
    else
        destroyPreview(inCharacterLobby and previewCam ~= nil)
    end
    sendCharacters()
    lobbyActionBusy = false
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    if lobbyActionBusy then
        cb({ ok = false, error = 'Please wait for the current character action.' })
        return
    end

    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character then cb({ ok = false, error = 'Select a character first.' }); return end

    lobbyActionBusy = true
    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    destroyPreview()
    local ok, err = pcall(function() lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid) end)
    if not ok then
        inCharacterLobby = false
        lobbyActionBusy = false
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
    lobbyActionBusy = false
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    if lobbyActionBusy then
        cb({ ok = false, error = 'Please wait for the current character action.' })
        return
    end

    local slot = tonumber(data.slot) or 1
    if slot < 1 or slot > maxCharacters or characters[slot] then
        cb({ ok = false, error = 'That character slot is unavailable.' })
        return
    end

    lobbyActionBusy = true
    local gender = data.gender == 'Female' and 1 or 0
    local result = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = tostring(data.firstname or ''), lastname = tostring(data.lastname or ''),
        nationality = tostring(data.nationality or ''), gender = gender,
        birthdate = tostring(data.birthdate or ''), cid = slot
    })
    if not result then
        lobbyActionBusy = false
        cb({ ok = false, error = 'Character creation failed. Check the information and try again.' })
        return
    end
    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    destroyPreview()
    restorePlayer()
    if GetResourceState('qbx_properties'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', result)
    elseif GetResourceState('qbx_spawn'):find('start') then
        TriggerEvent('qbx_core:client:spawnNoApartments')
    else
        DoScreenFadeIn(700)
    end
    lobbyActionBusy = false
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

CreateThread(function() print('[BotRP] character v0.6.1 started') end)