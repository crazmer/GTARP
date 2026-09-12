local RESOURCE = GetCurrentResourceName()
local config = require 'config'
local previewCam
local randomLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1

local function notify(message, kind)
    lib.notify({ title = 'BotRP', description = message, type = kind or 'inform' })
end

local function destroyPreview()
    if previewCam then
        SetTimecycleModifier('default')
        SetCamActive(previewCam, false)
        DestroyCam(previewCam, true)
        RenderScriptCams(false, false, 500, true, true)
        previewCam = nil
    end
    FreezeEntityPosition(cache.ped, false)
    DisplayRadar(true)
end

local function previewPed(citizenId)
    local clothing, model = citizenId and lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId) or nil
    if model and clothing then
        lib.requestModel(model, config.loadingModelsTimeout)
        SetPlayerModel(cache.playerId, model)
        pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(clothing)) end)
        SetModelAsNoLongerNeeded(model)
    else
        local modelHash = `mp_m_freemode_01`
        lib.requestModel(modelHash, config.loadingModelsTimeout)
        SetPlayerModel(cache.playerId, modelHash)
        SetModelAsNoLongerNeeded(modelHash)
    end
end

local function setupPreview()
    randomLocation = config.locations[math.random(1, #config.locations)]
    SetEntityCoords(cache.ped, randomLocation.pedCoords.x, randomLocation.pedCoords.y, randomLocation.pedCoords.z, false, false, false, false)
    SetEntityHeading(cache.ped, randomLocation.pedCoords.w)
    FreezeEntityPosition(cache.ped, true)
    DisplayRadar(false)
    SetEntityVisible(cache.ped, true, false)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(0.65)
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', randomLocation.camCoords.x, randomLocation.camCoords.y, randomLocation.camCoords.z, -6.0, 0.0, randomLocation.camCoords.w, 40.0, false, 0)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 750, true, true)
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
    characters, maxCharacters = lib.callback.await('qbx_core:server:getCharacters')
    characters = characters or {}
    maxCharacters = maxCharacters or #characters
    selectedIndex = 1

    NetworkStartSoloTutorialSession()
    while not NetworkIsInTutorialSession() do Wait(0) end

    local first = characters[1]
    previewPed(first and first.citizenid)
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
    previewPed(character and character.citizenid)
    sendCharacters()
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character then cb({ ok = false }); return end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'transition', text = 'Entering Los Santos...' })
    DoScreenFadeOut(250)
    Wait(250)

    -- qbx_core's loadCharacter callback intentionally has no return value on success.
    -- Do not treat a nil callback result as a failure; the authoritative success is Login()
    -- on the server. This mirrors qbx_core's own multicharacter flow.
    lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid)

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
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
    end

    destroyPreview()
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

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'transition', text = 'Creating your character...' })
    Wait(350)
    if GetResourceState('qbx_apartments'):find('start') then
        TriggerEvent('apartments:client:setupSpawnUI', result)
    elseif GetResourceState('qbx_spawn'):find('start') then
        TriggerEvent('qbx_core:client:spawnNoApartments')
    else
        local pos = config.defaultSpawn
        SetEntityCoords(cache.ped, pos.x, pos.y, pos.z, false, false, false, false)
        SetEntityHeading(cache.ped, pos.w)
        SetEntityVisible(cache.ped, true, false)
        DisplayRadar(true)
        DoScreenFadeIn(700)
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')
    end
    destroyPreview()
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
    if GetInvokingResource() then return end
    Wait(500)
    openCharacterScreen()
end)

CreateThread(function() print('[BotRP] character v0.1.3 started') end)
