local session = nil
local currentCharacter = nil
local spawned = false

local function notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 120, 190, 255 },
        multiline = true,
        args = { 'BotRP', message }
    })
end

local function loadModel(modelName)
    local model = GetHashKey(modelName)

    if not IsModelInCdimage(model) or not IsModelValid(model) then
        print(('[BotRP] ERROR: Invalid model %s'):format(modelName))
        return nil
    end

    RequestModel(model)

    local timeout = 0

    while not HasModelLoaded(model) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        print(('[BotRP] ERROR: Failed to load model %s'):format(modelName))
        return nil
    end

    return model
end

local function spawnCharacter(character)
    local spawn = BotRPConfig.Character.DefaultSpawn
    local modelName = character.model or BotRPConfig.Character.DefaultModel
    local model = loadModel(modelName)

    if not model then
        return false
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)

    Wait(500)

    local ped = PlayerPedId()

    SetPedDefaultComponentVariation(ped)
    ClearPedBloodDamage(ped)
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityAlpha(ped, 255, false)
    NetworkSetEntityInvisibleToNetwork(ped, false)

    NetworkResurrectLocalPlayer(
        spawn.x,
        spawn.y,
        spawn.z,
        spawn.w,
        true,
        true,
        false
    )

    Wait(250)

    ped = PlayerPedId()

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

    spawned = true

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(1000)

    print(('[BotRP] Character spawned: %s %s'):format(character.firstName, character.lastName))

    return true
end

local function printCharacters(characters)
    notify('Characters:')

    if #characters == 0 then
        notify('No characters found. Use /createchar First Last DD/MM/YYYY Nationality Gender')
        return
    end

    for _, character in ipairs(characters) do
        notify(('[%d] %s %s | DOB: %s | %s | %s'):format(
            character.id,
            character.firstName,
            character.lastName,
            character.dateOfBirth,
            character.nationality,
            character.gender
        ))
    end

    notify('Use /selectchar ID to enter the city.')
end

RegisterNetEvent('botrp:client:sessionReady', function(data)
    session = data

    print('[BotRP] Player session ready.')
    print(('[BotRP] Characters loaded: %d'):format(#(data.characters or {})))

    if #(data.characters or {}) == 0 then
        notify('Welcome to BotRP development.')
        notify('No character exists yet.')
        notify('Use /createchar First Last DD/MM/YYYY Nationality Gender')
    else
        notify(('Welcome back, %s.'):format(GetPlayerName(PlayerId()) or 'Player'))
        printCharacters(data.characters)
    end

    if not spawned then
        local tempCharacter = {
            firstName = 'Development',
            lastName = 'Player',
            model = BotRPConfig.Character.DefaultModel
        }

        spawnCharacter(tempCharacter)
    end
end)

RegisterNetEvent('botrp:client:characters', function(characters)
    if session then
        session.characters = characters
    end

    printCharacters(characters)
end)

RegisterNetEvent('botrp:client:characterResult', function(success, message)
    notify(message)
end)

RegisterNetEvent('botrp:client:characterSelected', function(character)
    currentCharacter = character

    notify(('Entering as %s %s.'):format(character.firstName, character.lastName))

    if spawnCharacter(character) then
        print(('[BotRP] Active character ID: %s'):format(character.id))
    end
end)

RegisterCommand('characters', function()
    TriggerServerEvent('botrp:server:requestCharacters')
end, false)

RegisterCommand('createchar', function(_, args)
    if #args < 5 then
        notify('Usage: /createchar First Last DD/MM/YYYY Nationality Gender')
        return
    end

    TriggerServerEvent(
        'botrp:server:createCharacter',
        args[1],
        args[2],
        args[3],
        args[4],
        string.lower(args[5])
    )
end, false)

RegisterCommand('selectchar', function(_, args)
    local id = tonumber(args[1])

    if not id then
        notify('Usage: /selectchar ID')
        return
    end

    TriggerServerEvent('botrp:server:selectCharacter', id)
end, false)

CreateThread(function()
    print('[BotRP] Client core initialized.')

    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    print('[BotRP] Network session started.')
end)
