local config = require 'config'
local previewCam
local previewPedEntity
local previewLocation
local characters = {}
local maxCharacters = 0
local selectedIndex = 1
local inCharacterLobby = false

local function setGameplayHudVisible(visible)
    DisplayRadar(visible)
    DisplayHud(visible)

    -- qbx_hud is a separate NUI. Its normal update loop can redraw itself after
    -- the character screen opens, so keep explicitly hiding it while the lobby
    -- owns the screen and restore it only after the character is loaded.
    if GetResourceState('qbx_hud') == 'started' then
        SendNUIMessage({ action = 'hudtick', show = visible })
        SendNUIMessage({ action = 'car', show = visible and cache.vehicle ~= nil })
    end
end

local function closeCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    inCharacterLobby = false
end

local function destroyPreview()
    if previewCam then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 250, true, true)
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

    if clothing and type(clothing) == 'string' and GetResourceState('illenium-appearance') == 'started' then
        pcall(function()
            local appearance = json.decode(clothing)
            if appearance then
                exports['illenium-appearance']:setPedAppearance(previewPedEntity, appearance)
            end
        end)
    end

    SetModelAsNoLongerNeeded(modelHash)

    local heading = math.rad(coords.w)
    local forwardX = -math.sin(heading)
    local forwardY = math.cos(heading)
    local camX = coords.x + forwardX * 2.8
    local camY = coords.y + forwardY * 2.8
    local camZ = coords.z + 1.35

    previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(previewCam, camX, camY, camZ)
    SetCamFov(previewCam, 42.0)
    PointCamAtEntity(previewCam, previewPedEntity, 0.0, 0.0, 0.95, true)
    SetCamActive(previewCam, true)
    SetCamUseShallowDofMode(previewCam, true)
    SetCamNearDof(previewCam, 0.8)
    SetCamFarDof(previewCam, 8.0)
    SetCamDofStrength(previewCam, 0.55)
    RenderScriptCams(true, false, 500, true, true)
    SetTimecycleModifier('hud_def_blur')
    SetTimecycleModifierStrength(0.18)
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
    DoScreenFadeOut(10)
    Wait(20)
    destroyPreview()

    local ok, err = pcall(function()
        lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid)
    end)

    if not ok then
        inCharacterLobby = false
        setGameplayHudVisible(true)
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
        setGameplayHudVisible(true)
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

-- Keep gameplay HUD elements suppressed while BotRP owns the character lobby.
-- qbx_hud has its own periodic update loop, so a one-time hide is not enough.
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

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    Wait(500)
    openCharacterScreen()
end)

CreateThread(function() print('[BotRP] character v0.1.9 started') end)
