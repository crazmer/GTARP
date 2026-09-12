local config = require 'config'
local previewCam
local previewPedEntity
local previewLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1
local inCharacterLobby = false
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
    setGameplayHudVisible(true)
end

local function closeCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    inCharacterLobby = false
end

local function destroyPreview()
    if previewCam then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 350, true, true)
        DestroyCam(previewCam, true)
        previewCam = nil
    end

    if previewPedEntity and DoesEntityExist(previewPedEntity) then
        SetEntityAsMissionEntity(previewPedEntity, true, true)
        DeleteEntity(previewPedEntity)
        previewPedEntity = nil
    end

    ClearTimecycleModifier()
end

local function getModelHash(model)
    if type(model) == 'string' then return joaat(model) end
    return model
end

local function requestPreviewAnimation()
    if not lib then return false end
    if not lib.requestAnimDict then return false end

    local ok = pcall(function()
        lib.requestAnimDict(previewAnimDict)
    end)
    return ok
end

local function createPreviewPed(citizenId)
    destroyPreview()

    previewLocation = config.locations[1]
    local coords = previewLocation.pedCoords
    local clothing, model = nil, nil

    if citizenId then
        clothing, model = lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
    end

    local modelHash = getModelHash(model) or `mp_m_freemode_01`
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        modelHash = `mp_m_freemode_01`
    end

    lib.requestModel(modelHash, config.loadingModelsTimeout)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    previewPedEntity = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityAsMissionEntity(previewPedEntity, true, true)
    SetEntityInvincible(previewPedEntity, true)
    SetEntityCollision(previewPedEntity, false, false)
    FreezeEntityPosition(previewPedEntity, true)
    SetEntityVisible(previewPedEntity, true, false)
    ResetEntityAlpha(previewPedEntity)
    SetBlockingOfNonTemporaryEvents(previewPedEntity, true)
    ClearPedTasksImmediately(previewPedEntity)
    SetPedCanRagdoll(previewPedEntity, false)
    SetPedFleeAttributes(previewPedEntity, 0, false)
    SetPedCombatAttributes(previewPedEntity, 46, true)

    if clothing and type(clothing) == 'string' and GetResourceState('illenium-appearance') == 'started' then
        pcall(function()
            local appearance = json.decode(clothing)
            if appearance then
                exports['illenium-appearance']:setPedAppearance(previewPedEntity, appearance)
            end
        end)
    end

    -- Give the character a natural showcase idle instead of standing rigidly.
    if requestPreviewAnimation() then
        TaskPlayAnim(previewPedEntity, previewAnimDict, previewAnimName, 2.0, 2.0, -1, 1, 0.0, false, false, false)
    else
        TaskStartScenarioInPlace(previewPedEntity, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end

    SetModelAsNoLongerNeeded(modelHash)

    -- Use the configured showcase camera when available. It is intentionally
    -- independent from the real player so changing characters never moves them.
    local cam = previewLocation.camCoords
    local camX, camY, camZ
    if cam then
        camX, camY, camZ = cam.x, cam.y, cam.z
    else
        local heading = math.rad(coords.w)
        camX = coords.x - math.sin(heading) * 2.8
        camY = coords.y + math.cos(heading) * 2.8
        camZ = coords.z + 1.35
    end

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, camX, camY, camZ)
    SetCamFov(previewCam, 38.0)
    PointCamAtEntity(previewCam, previewPedEntity, 0.0, 0.0, 0.98, true)
    SetCamActive(previewCam, true)
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 1.0)
    SetCamFarDof(previewCam, 10.0)
    SetCamDofStrength(previewCam, 0.72)
    RenderScriptCams(true, false, 650, true, true)

    -- A subtle cinematic grade; the actual world remains visible behind the UI.
    SetTimecycleModifier('MP_corona_switch')
    SetTimecycleModifierStrength(0.10)
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

    local ok, err = pcall(function()
        lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid)
    end)

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

-- Keep gameplay HUD elements suppressed while BotRP owns the character lobby.
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

-- Tiny camera breathing motion makes the showcase feel alive without moving
-- the character around the world or affecting gameplay.
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

CreateThread(function() print('[BotRP] character v0.2.0 started') end)
