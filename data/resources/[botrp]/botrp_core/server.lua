local RESOURCE = GetCurrentResourceName()

local sessions = {}
local players = {}

local function log(message)
    print(('[BotRP] %s'):format(message))
end

local function getIdentifier(source)
    local license = GetPlayerIdentifierByType(source, 'license')

    if license and license ~= '' then
        return license
    end

    return ('source:%s'):format(source)
end

local function loadPlayers()
    local raw = LoadResourceFile(RESOURCE, BotRPConfig.StorageFile)

    if not raw or raw == '' then
        players = {}
        SaveResourceFile(RESOURCE, BotRPConfig.StorageFile, '{}\n', -1)
        return
    end

    local decoded = json.decode(raw)

    if type(decoded) ~= 'table' then
        log('WARNING: players.json is invalid. Starting with empty player data.')
        players = {}
        return
    end

    players = decoded
end

local function savePlayers()
    local encoded = json.encode(players)

    if not encoded then
        log('ERROR: Failed to encode player data.')
        return false
    end

    SaveResourceFile(RESOURCE, BotRPConfig.StorageFile, encoded, -1)
    return true
end

local function getPlayerData(identifier)
    players[identifier] = players[identifier] or {
        characters = {}
    }

    players[identifier].characters = players[identifier].characters or {}

    return players[identifier]
end

local function sanitize(value, maxLength)
    if type(value) ~= 'string' then
        return nil
    end

    value = value:gsub('[\r\n]', ''):gsub('^%s+', ''):gsub('%s+$', '')

    if value == '' or #value > maxLength then
        return nil
    end

    return value
end

local function validateCharacterInput(firstName, lastName, dob, nationality, gender)
    firstName = sanitize(firstName, 32)
    lastName = sanitize(lastName, 32)
    dob = sanitize(dob, 16)
    nationality = sanitize(nationality, 32)
    gender = sanitize(gender, 16)

    if not firstName or not lastName or not dob or not nationality or not gender then
        return false
    end

    if not firstName:match('^[%a%s%-]+$') or not lastName:match('^[%a%s%-]+$') then
        return false
    end

    if gender ~= 'male' and gender ~= 'female' and gender ~= 'other' then
        return false
    end

    return firstName, lastName, dob, nationality, gender
end

local function createCharacter(identifier, firstName, lastName, dob, nationality, gender)
    local playerData = getPlayerData(identifier)
    local characters = playerData.characters

    if #characters >= BotRPConfig.Character.MaxCharacters then
        return nil, 'Character limit reached.'
    end

    local characterId = 1

    for _, character in ipairs(characters) do
        if tonumber(character.id) and character.id >= characterId then
            characterId = character.id + 1
        end
    end

    local character = {
        id = characterId,
        firstName = firstName,
        lastName = lastName,
        dateOfBirth = dob,
        nationality = nationality,
        gender = gender,
        model = BotRPConfig.Character.DefaultModel,
        createdAt = os.time()
    }

    characters[#characters + 1] = character

    if not savePlayers() then
        characters[#characters] = nil
        return nil, 'Failed to save character data.'
    end

    return character
end

RegisterNetEvent('botrp:server:requestCharacters', function()
    local source = source
    local session = sessions[source]

    if not session then
        return
    end

    TriggerClientEvent(
        'botrp:client:characters',
        source,
        getPlayerData(session.identifier).characters
    )
end)

RegisterNetEvent('botrp:server:createCharacter', function(firstName, lastName, dob, nationality, gender)
    local source = source
    local session = sessions[source]

    if not session then
        return
    end

    local validFirst, validLast, validDob, validNationality, validGender =
        validateCharacterInput(firstName, lastName, dob, nationality, gender)

    if not validFirst then
        TriggerClientEvent(
            'botrp:client:characterResult',
            source,
            false,
            'Invalid character information.'
        )
        return
    end

    local character, errorMessage = createCharacter(
        session.identifier,
        validFirst,
        validLast,
        validDob,
        validNationality,
        validGender
    )

    if not character then
        TriggerClientEvent(
            'botrp:client:characterResult',
            source,
            false,
            errorMessage or 'Failed to create character.'
        )
        return
    end

    log(('Character created for %s: %s %s'):format(
        session.identifier,
        character.firstName,
        character.lastName
    ))

    TriggerClientEvent(
        'botrp:client:characterResult',
        source,
        true,
        'Character created successfully.',
        character
    )

    TriggerClientEvent(
        'botrp:client:characters',
        source,
        getPlayerData(session.identifier).characters
    )
end)

RegisterNetEvent('botrp:server:selectCharacter', function(characterId)
    local source = source
    local session = sessions[source]

    if not session then
        return
    end

    characterId = tonumber(characterId)

    if not characterId then
        TriggerClientEvent('botrp:client:characterResult', source, false, 'Invalid character ID.')
        return
    end

    local characters = getPlayerData(session.identifier).characters

    for _, character in ipairs(characters) do
        if tonumber(character.id) == characterId then
            session.character = character

            TriggerClientEvent(
                'botrp:client:characterSelected',
                source,
                character
            )

            log(('Character selected by %s: %s %s'):format(
                session.identifier,
                character.firstName,
                character.lastName
            ))

            return
        end
    end

    TriggerClientEvent(
        'botrp:client:characterResult',
        source,
        false,
        'Character not found.'
    )
end)

AddEventHandler('playerJoining', function()
    local source = source
    local identifier = getIdentifier(source)

    sessions[source] = {
        identifier = identifier,
        character = nil
    }

    getPlayerData(identifier)

    log(('Player session created: %s (%s)'):format(
        GetPlayerName(source) or 'Unknown',
        identifier
    ))

    SetTimeout(1000, function()
        if GetPlayerName(source) then
            local playerData = getPlayerData(identifier)

            TriggerClientEvent('botrp:client:sessionReady', source, {
                identifier = identifier,
                characters = playerData.characters
            })
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local source = source
    local session = sessions[source]

    if session then
        log(('Player session closed: %s (%s)'):format(
            GetPlayerName(source) or 'Unknown',
            session.identifier
        ))
    end

    sessions[source] = nil
end)

CreateThread(function()
    loadPlayers()

    print('========================================')
    print('        BotRP Core Initializing')
    print('========================================')
    print('[BotRP] Framework: Custom')
    print(('[BotRP] Version: %s'):format(BotRPConfig.Version))
    print('[BotRP] QBCore: Disabled')
    print('[BotRP] Qbox: Disabled')
    print('[BotRP] ESX: Disabled')
    print('[BotRP] Player sessions: Enabled')
    print('[BotRP] Character system: Enabled')
    print('[BotRP] Storage: JSON')
    print('[BotRP] Core initialized successfully.')
    print('========================================')
end)
