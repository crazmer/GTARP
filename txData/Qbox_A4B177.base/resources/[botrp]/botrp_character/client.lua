local config = require 'config'
local previewCam
local randomLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1
local inCharacterLobby = false

local function closeCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    inCharacterLobby = false
end

local function destroyPreview()
    if previewCam then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 500, true, true)
        DestroyCam(previewCam, true)
        previewCam = nil
    end
    ClearTimecycleModifier()
    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)
    SetEntityCollision(cache.ped, true, true)
    DisplayRadar(true)
end

local function loadPreviewPed(citizenId)
    local clothing, model = citizenId and lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId) or nil
    if model and clothing then
        lib.requestModel(model, config.loadingModelsTimeout)
        SetPlayerModel(cache.playerId, model)
        pcall(function()
            local appearance = json.decode(clothing)
            if appearance and GetResourceState('illenium-appearance') == 'started' then
                exports['illenium-appearance']:setPedAppearance(PlayerPedId(), appearance)
            end
        end)
        SetModelAsNoLongerNeeded(model)
    else
        local modelHash = `mp_m_freemode_01`
        lib.requestModel(modelHash, config.loadingModelsTimeout)
        SetPlayerModel(cache.playerId, modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    end

    SetEntityVisible(cache.ped, true, false)
    SetEntityInvincible(cache.ped, true)
    SetEntityCollision(cache.ped, false, false)
    ClearPedTasksImmediately(cache.ped)
end

local function setupPreview()
    destroyPreview()
    randomLocation = config.locations[math.random(1, #config.locations)]

    RequestCollisionAtCoord(randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z)
    SetEntityCoordsNoOffset(cache.ped, randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z, false, false, false)
    SetEntityHeading(cache.ped, randomLocation.pedCoords.w)
    FreezeEntityPosition(cache.ped, true)
    DisplayRadar(false)
    SetEntityVisible(cache.ped, true, false)
    SetEntityInvincible(cache.ped, true)
    SetEntityCollision(cache.ped, false, false)

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, randomLocation.camCoords.x, randomLocation.camCoords.y, randomLocation.camCoords.z)
    SetCamFov(previewCam, 38.0)
    PointCamAtEntity(previewCam, cache.ped, 0.0, 0.0, 0.72, true)
    SetCamActive(previewCam, true)
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 0.4)
    SetCamFarDof(previewCam, 2.2)
    SetCamDofStrength(previewCam, 0.75)
    RenderScriptCams(true, false, 750, true, true)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(0.25)
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

    characters, maxCharacters = lib.callback.await('qbx_core:server:getCharacters')
    characters = characters or {}
    maxCharacters = maxCharacters or #characters
    selectedIndex = 1

    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end

    local first = characters[1]
    loadPreviewPed(first and first.citizenid)
    setupPreview()

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
    loadPreviewPed(character and character.citizenid)
    setupPreview()
    sendCharacters()
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character then cb({ ok = false, error = 'Select a character first.' }); return end

    -- Match Qbox's native external-character handoff: login first, then let the
    -- apartment/spawn resource open its own UI. Do not fabricate a success value.
    closeCharacterUI()
    DoScreenFadeOut(10)
    Wait(20)
    destroyPreview()

    local ok, err = pcall(function()
        lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid)
    end)

    if not ok then
        inCharacterLobby = false
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
        SetEntityVisible(cache.ped, true, false)
        DisplayRadar(true)
        DoScreenFadeIn(700)
    end

    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    local slot = tonumber(data.slot) or 1
    if slot < 1 or slot > maxCharacters or characters[slot] then cb({ ok = false, error = 'That character slot is unavailable.' }); return end
    local gender = data.gender == 'Female' and 1 or 0
    local result = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = tostring(data.firstname or ''), lastname = tostring(data.lastname or ''),
        nationality = tostring(data.nationality or ''), gender = gender,
        birthdate = tostring(data.birthdate or ''), cid = slot
    })
    if not result then cb({ ok = false, error = 'Character creation failed. Check the information and try again.' }); return end

    closeCharacterUI()
    DoScreenFadeOut(10)
    Wait(20)
    destroyPreview()
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

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    Wait(500)
    openCharacterScreen()
end)

CreateThread(function() print('[BotRP] character v0.1.7 started') end)
