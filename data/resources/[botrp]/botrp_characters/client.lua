local currentCharacter = nil

local function notify(message)
    exports.botrp_bridge:Notify(message, 'inform')
end

local function loadModel(modelName)
    local model = joaat(modelName)

    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print(('[BotRP Characters] Invalid model: %s'):format(modelName))
        return nil
    end

    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        print(('[BotRP Characters] Failed to load model: %s'):format(modelName))
        return nil
    end

    return model
end

local function spawnCharacter(character)
    local spawn = BotRPCharactersConfig.DefaultSpawn
    local model = loadModel(character.model or BotRPCharactersConfig.DefaultModel)

    if not model then return false end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    Wait(300)

    NetworkResurrectLocalPlayer(spawn.x, spawn.y, spawn.z, spawn.w, true, true, false)
    Wait(250)

    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    ClearPedBloodDamage(ped)
    SetEntityCoordsNoOffset(ped, spawn.x, spawn.y, spawn.z, false, false, false)
    SetEntityHeading(ped, spawn.w)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetPlayerControl(PlayerId(), true, 0)
    FreezeEntityPosition(ped, false)
    SetEntityCollision(ped, true, true)
    ClearPedTasksImmediately(ped)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(1000)

    return true
end

RegisterNetEvent('botrp:characters:list', function(characters)
    SendNUIMessage({
        action = 'open',
        characters = characters or {}
    })
    SetNuiFocus(true, true)

    local ped = PlayerPedId()
    SetPlayerControl(PlayerId(), false, 0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
end)

RegisterNetEvent('botrp:characters:result', function(success, message)
    notify(message)
    SendNUIMessage({ action = 'message', message = message })
end)

RegisterNetEvent('botrp:characters:selected', function(character)
    currentCharacter = character

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    notify(('Entering as %s %s.'):format(character.firstName, character.lastName))

    if spawnCharacter(character) then
        print(('[BotRP Characters] Active character: %s %s'):format(character.firstName, character.lastName))
    end
end)

RegisterNUICallback('createCharacter', function(data, cb)
    TriggerServerEvent(
        'botrp:characters:create',
        data.firstName,
        data.lastName,
        data.dateOfBirth,
        data.nationality,
        data.gender
    )
    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('botrp:characters:select', data.id)
    cb({ ok = true })
end)

RegisterCommand('characters', function()
    TriggerServerEvent('botrp:characters:request')
end, false)

RegisterCommand('createchar', function(_, args)
    if #args < 5 then
        notify('Usage: /createchar First Last DD/MM/YYYY Nationality Gender')
        return
    end

    TriggerServerEvent('botrp:characters:create', args[1], args[2], args[3], args[4], string.lower(args[5]))
end, false)

RegisterCommand('selectchar', function(_, args)
    local id = tonumber(args[1])
    if not id then
        notify('Usage: /selectchar ID')
        return
    end

    TriggerServerEvent('botrp:characters:select', id)
end, false)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('botrp:characters:request')
end)

exports('GetCurrentCharacter', function()
    return currentCharacter
end)
