local config = require 'config'

local previewCam
local previewPed
local previewLocation
local characters = {}
local maxCharacters = 1
local selectedIndex = 1
local inCharacterLobby = false
local lobbyActionBusy = false
local showcaseReady = false

local function hudVisible(visible)
    DisplayRadar(visible)
    DisplayHud(visible)
    if GetResourceState('qbx_hud') == 'started' then
        SendNUIMessage({ action = 'hudtick', show = visible })
        SendNUIMessage({ action = 'car', show = visible and cache.vehicle ~= nil })
    end
end

local function deletePreviewPed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeletePed(ped)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
end

local function cleanupPreview()
    if previewCam and DoesCamExist(previewCam) then
        SetCamActive(previewCam, false)
        RenderScriptCams(false, false, 200, true, true)
        DestroyCam(previewCam, true)
    end
    previewCam = nil

    deletePreviewPed(previewPed)
    previewPed = nil

    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()
    ClearTimecycleModifier()
    NetworkClearClockTimeOverride()
    SetArtificialLightsState(false)
end

local function restorePlayer()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetFocusEntity(ped)
    hudVisible(true)
end

local function closeCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    inCharacterLobby = false
    showcaseReady = false
end

local function sendCharacters()
    local payload = {}
    for i = 1, maxCharacters do
        local c = characters[i]
        if c then
            payload[#payload + 1] = {
                slot = i,
                citizenid = c.citizenid,
                firstname = c.charinfo and c.charinfo.firstname or '',
                lastname = c.charinfo and c.charinfo.lastname or '',
                birthdate = c.charinfo and c.charinfo.birthdate or '',
                gender = c.charinfo and c.charinfo.gender == 0 and 'Male' or 'Female',
                nationality = c.charinfo and c.charinfo.nationality or '',
                job = c.job and c.job.label or 'Unemployed',
                jobGrade = c.job and c.job.grade and c.job.grade.name or '',
                cash = c.money and c.money.cash or 0,
                bank = c.money and c.money.bank or 0,
                phone = c.charinfo and c.charinfo.phone or ''
            }
        else
            payload[#payload + 1] = { slot = i, empty = true }
        end
    end
    SendNUIMessage({ action = 'characters', characters = payload, selected = selectedIndex })
end

local function loadCharacters()
    local ok, result, slots = pcall(function()
        return lib.callback.await('qbx_core:server:getCharacters')
    end)
    if ok and type(result) == 'table' then
        characters = result
        maxCharacters = tonumber(slots) or #characters
    else
        print(('[BotRP] character list callback failed: %s'):format(tostring(result)))
        characters = {}
        maxCharacters = 1
    end

    if maxCharacters < 1 then maxCharacters = 1 end
    if selectedIndex > maxCharacters then selectedIndex = maxCharacters end
    sendCharacters()
    return characters
end

local function streamShowcaseScene(pedCoords, camCoords)
    local focusX = (pedCoords.x + camCoords.x) * 0.5
    local focusY = (pedCoords.y + camCoords.y) * 0.5
    local focusZ = (pedCoords.z + camCoords.z) * 0.5

    SetFocusPosAndVel(focusX, focusY, focusZ, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
    RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
    RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
    RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

    if NewLoadSceneStartSphere then
        pcall(function()
            NewLoadSceneStartSphere(focusX, focusY, focusZ, 220.0, 0)
        end)
    end

    local deadline = GetGameTimer() + 7000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
        RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

        if not IsNewLoadSceneActive or not IsNewLoadSceneActive() or IsNewLoadSceneLoaded() then
            break
        end
        Wait(0)
    end
end

local function waitForPreviewCollision(pedCoords, camCoords)
    local deadline = GetGameTimer() + 3000
    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
        RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
        Wait(0)
    end
end

local function createOrUpdatePreview(citizenId)
    previewLocation = config.locations and config.locations[1]
    if not previewLocation or not previewLocation.pedCoords then return false end

    local coords = previewLocation.pedCoords
    local camCoords = previewLocation.camCoords or vec4(coords.x - 2.8, coords.y, coords.z + 1.2, 0.0)

    streamShowcaseScene(coords, camCoords)

    local modelHash = `mp_m_freemode_01`
    local clothing

    if citizenId then
        local ok, model, appearance = pcall(function()
            return lib.callback.await('qbx_core:server:getPreviewPedData', false, citizenId)
        end)
        if ok then
            if type(model) == 'string' then modelHash = joaat(model)
            elseif type(model) == 'number' then modelHash = model end
            clothing = appearance
        end
    end

    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        modelHash = `mp_m_freemode_01`
    end

    RequestModel(modelHash)
    local modelDeadline = GetGameTimer() + 10000
    while not HasModelLoaded(modelHash) and GetGameTimer() < modelDeadline do
        Wait(0)
    end

    if not HasModelLoaded(modelHash) then
        if NewLoadSceneStop then NewLoadSceneStop() end
        ClearFocus()
        print('[BotRP] preview model failed to load')
        return false
    end

    local oldPed = previewPed
    local newPed = CreatePed(4, modelHash, coords.x, coords.y, coords.z, coords.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not newPed or newPed == 0 or not DoesEntityExist(newPed) then
        if NewLoadSceneStop then NewLoadSceneStop() end
        ClearFocus()
        print('[BotRP] preview ped failed to create')
        return false
    end

    previewPed = newPed
    SetEntityAsMissionEntity(newPed, true, true)
    SetEntityInvincible(newPed, true)
    SetEntityCollision(newPed, false, false)
    FreezeEntityPosition(newPed, true)
    SetBlockingOfNonTemporaryEvents(newPed, true)
    SetPedCanRagdoll(newPed, false)
    SetPedFleeAttributes(newPed, 0, false)
    SetPedCombatAttributes(newPed, 46, true)

    if clothing and type(clothing) == 'string' and GetResourceState('illenium-appearance') == 'started' then
        pcall(function()
            local appearance = json.decode(clothing)
            if appearance then exports['illenium-appearance']:setPedAppearance(newPed, appearance) end
        end)
    end

    local heading = GetHeadingFromVector_2d(camCoords.x - coords.x, camCoords.y - coords.y)
    SetEntityHeading(newPed, heading)

    RequestAnimDict('amb@world_human_stand_impatient@male@base')
    local animDeadline = GetGameTimer() + 4000
    while not HasAnimDictLoaded('amb@world_human_stand_impatient@male@base') and GetGameTimer() < animDeadline do
        Wait(0)
    end
    if HasAnimDictLoaded('amb@world_human_stand_impatient@male@base') then
        TaskPlayAnim(newPed, 'amb@world_human_stand_impatient@male@base', 'base', 2.0, 2.0, -1, 1, 0.0, false, false, false)
    end

    waitForPreviewCollision(coords, camCoords)

    if not previewCam or not DoesCamExist(previewCam) then
        previewCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
        SetCamFov(previewCam, 38.0)
        SetCamActive(previewCam, true)
        SetCamUseShallowDofMode(previewCam, true)
        SetCamNearDof(previewCam, 1.2)
        SetCamFarDof(previewCam, 18.0)
        SetCamDofStrength(previewCam, 0.18)
        PointCamAtEntity(previewCam, newPed, 0.0, 0.0, 1.0, true)
        RenderScriptCams(true, false, 700, true, true)
    else
        SetCamCoord(previewCam, camCoords.x, camCoords.y, camCoords.z)
        PointCamAtEntity(previewCam, newPed, 0.0, 0.0, 1.0, true)
        SetCamFov(previewCam, 38.0)
    end

    SetTimecycleModifier('default')
    SetTimecycleModifierStrength(0.0)
    NetworkOverrideClockTime(19, 45, 0)
    SetArtificialLightsState(false)

    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()

    if oldPed and oldPed ~= newPed then
        deletePreviewPed(oldPed)
    end

    return true
end

local function openCharacterScreen()
    if inCharacterLobby then return end

    inCharacterLobby = true
    lobbyActionBusy = false
    showcaseReady = false
    selectedIndex = 1

    hudVisible(false)

    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    SetEntityCollision(playerPed, false, false)
    SetEntityVisible(playerPed, false, false)

    -- Keep the game fully hidden while the remote showcase scene streams.
    DoScreenFadeOut(0)

    CreateThread(function()
        loadCharacters()
        local first = characters[selectedIndex]
        local ready = createOrUpdatePreview(first and first.citizenid)

        if not inCharacterLobby then
            cleanupPreview()
            return
        end

        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
        sendCharacters()

        if ready then
            showcaseReady = true
            DoScreenFadeIn(650)
        else
            -- Never expose the game world in a broken preview state.
            inCharacterLobby = false
            restorePlayer()
            SetNuiFocus(false, false)
            DoScreenFadeIn(500)
            SendNUIMessage({ action = 'hide' })
        end
    end)
end

RegisterNUICallback('select', function(data, cb)
    local index = tonumber(data.slot) or 1
    if index < 1 or index > maxCharacters then cb({ ok = false }); return end
    if lobbyActionBusy or not showcaseReady then
        cb({ ok = false, error = 'Please wait for the character preview.' })
        return
    end

    selectedIndex = index
    local character = characters[index]
    if character then
        lobbyActionBusy = true
        CreateThread(function()
            local ok = createOrUpdatePreview(character.citizenid)
            lobbyActionBusy = false
            sendCharacters()
            if not ok then
                print('[BotRP] failed to update character preview')
            end
        end)
    end

    sendCharacters()
    cb({ ok = true })
end)

RegisterNUICallback('delete', function(data, cb)
    if lobbyActionBusy or not showcaseReady then cb({ ok = false, error = 'Please wait for the current action.' }); return end
    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character or not character.citizenid then cb({ ok = false, error = 'Character not found.' }); return end

    lobbyActionBusy = true
    local ok, deleted = pcall(function()
        return lib.callback.await('botrp_character:server:deleteCharacter', false, character.citizenid)
    end)
    if not ok or not deleted then
        lobbyActionBusy = false
        cb({ ok = false, error = 'Character could not be deleted.' })
        return
    end

    loadCharacters()
    local replacement = characters[selectedIndex]
    createOrUpdatePreview(replacement and replacement.citizenid)
    lobbyActionBusy = false
    cb({ ok = true })
end)

RegisterNUICallback('play', function(data, cb)
    if lobbyActionBusy or not showcaseReady then cb({ ok = false, error = 'Please wait for the current action.' }); return end
    local index = tonumber(data.slot) or selectedIndex
    local character = characters[index]
    if not character then cb({ ok = false, error = 'Select a character first.' }); return end

    lobbyActionBusy = true
    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    cleanupPreview()

    local ok, err = pcall(function()
        return lib.callback.await('qbx_core:server:loadCharacter', false, character.citizenid)
    end)
    if not ok then
        lobbyActionBusy = false
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
            SetEntityCoords(PlayerPedId(), pos.x, pos.y, pos.z, false, false, false, false)
            SetEntityHeading(PlayerPedId(), pos.w or 0.0)
        end
        restorePlayer()
        DoScreenFadeIn(700)
    end

    lobbyActionBusy = false
    cb({ ok = true })
end)

RegisterNUICallback('create', function(data, cb)
    if lobbyActionBusy or not showcaseReady then cb({ ok = false, error = 'Please wait for the current action.' }); return end
    local slot = tonumber(data.slot) or 1
    if slot < 1 or slot > maxCharacters or characters[slot] then cb({ ok = false, error = 'That character slot is unavailable.' }); return end

    lobbyActionBusy = true
    local result = lib.callback.await('qbx_core:server:createCharacter', false, {
        firstname = tostring(data.firstname or ''),
        lastname = tostring(data.lastname or ''),
        nationality = tostring(data.nationality or ''),
        gender = data.gender == 'Female' and 1 or 0,
        birthdate = tostring(data.birthdate or ''),
        cid = slot
    })
    if not result then
        lobbyActionBusy = false
        cb({ ok = false, error = 'Character creation failed. Check the information and try again.' })
        return
    end

    closeCharacterUI()
    DoScreenFadeOut(250)
    Wait(280)
    cleanupPreview()
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

RegisterNUICallback('close', function(_, cb)
    cb({ ok = false })
end)

RegisterNetEvent('botrp_character:client:open', openCharacterScreen)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    Wait(1500)
    openCharacterScreen()
end)

CreateThread(function()
    while true do
        if inCharacterLobby then
            hudVisible(false)
            HideHudAndRadarThisFrame()
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 75, true)
            NetworkOverrideClockTime(19, 45, 0)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        if inCharacterLobby and previewCam and DoesCamExist(previewCam) and previewLocation and previewLocation.camCoords then
            local cam = previewLocation.camCoords
            SetCamCoord(previewCam, cam.x, cam.y, cam.z)
            if previewPed and DoesEntityExist(previewPed) then
                PointCamAtEntity(previewCam, previewPed, 0.0, 0.0, 1.0, true)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    Wait(500)
    openCharacterScreen()
end)

CreateThread(function()
    print('[BotRP] character v1.0.2 started (stable handoff + showcase swap)')
end)