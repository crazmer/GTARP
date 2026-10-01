local sessions = {}
local players = {}

local function log(message)
    print(('[BotRP Characters] %s'):format(message))
end

local function loadPlayers()
    local raw = LoadResourceFile(GetCurrentResourceName(), BotRPCharactersConfig.StorageFile)

    if not raw or raw == '' then
        players = {}
        SaveResourceFile(GetCurrentResourceName(), BotRPCharactersConfig.StorageFile, '{}\n', -1)
        return
    end

    local decoded = json.decode(raw)

    if type(decoded) ~= 'table' then
        log('WARNING: character storage is invalid; starting empty.')
        players = {}
        return
    end

    players = decoded
end

local function savePlayers()
    local encoded = json.encode(players)
    if not encoded then
        log('ERROR: failed to encode character storage.')
        return false
    end

    SaveResourceFile(GetCurrentResourceName(), BotRPCharactersConfig.StorageFile, encoded, -1)
    return true
end

local function getPlayerData(identifier)
    players[identifier] = players[identifier] or { characters = {} }
    players[identifier].characters = players[identifier].characters or {}
    return players[identifier]
end

local function sanitize(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[\\r\\n]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    if value == '' or #value > maxLength then return nil end
    return value
end

local function validate(firstName, lastName, dob, nationality, gender)
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
    local characters = getPlayerData(identifier).characters

    if #characters >= BotRPCharactersConfig.MaxCharacters then
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
        model = BotRPCharactersConfig.DefaultModel,
        createdAt = os.time()
    }

    characters[#characters + 1] = character

    if not savePlayers() then
        characters[#characters] = nil
        return nil, 'Failed to save character data.'
    end

    return character
end

local function sendCharacters(source)
    local identifier = exports.botrp_bridge:GetIdentifier(source)
    TriggerClientEvent('botrp:characters:list', source, getPlayerData(identifier).characters)
end

RegisterNetEvent('botrp:characters:request', function()
    sendCharacters(source)
end)

RegisterNetEvent('botrp:characters:create', function(firstName, lastName, dob, nationality, gender)
    local source = source
    local identifier = exports.botrp_bridge:GetIdentifier(source)

    local a, b, c, d, e = validate(firstName, lastName, dob, nationality, gender)

    if not a then
        TriggerClientEvent('botrp:characters:result', source, false, 'Invalid character information.')
        return
    end

    local character, errorMessage = createCharacter(identifier, a, b, c, d, e)

    if not character then
        TriggerClientEvent('botrp:characters:result', source, false, errorMessage)
        return
    end

    log(('Character created for %s: %s %s'):format(identifier, character.firstName, character.lastName))

    TriggerClientEvent('botrp:characters:result', source, true, 'Character created successfully.', character)
    sendCharacters(source)
end)

RegisterNetEvent('botrp:characters:select', function(characterId)
    local source = source
    local identifier = exports.botrp_bridge:GetIdentifier(source)
    characterId = tonumber(characterId)

    if not characterId then
        TriggerClientEvent('botrp:characters:result', source, false, 'Invalid character ID.')
        return
    end

    for _, character in ipairs(getPlayerData(identifier).characters) do
        if tonumber(character.id) == characterId then
            sessions[source] = character

            TriggerClientEvent('botrp:characters:selected', source, character)
            log(('Character selected by %s: %s %s'):format(identifier, character.firstName, character.lastName))
            return
        end
    end

    TriggerClientEvent('botrp:characters:result', source, false, 'Character not found.')
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

exports('GetCharacter', function(source)
    return sessions[source]
end)

exports('GetCharacters', function(source)
    local identifier = exports.botrp_bridge:GetIdentifier(source)
    return getPlayerData(identifier).characters
end)

CreateThread(function()
    loadPlayers()

    print('========================================')
    print('       BotRP Characters Initialized')
    print('========================================')
    print(('[BotRP Characters] Max characters: %d'):format(BotRPCharactersConfig.MaxCharacters))
    print('[BotRP Characters] Storage: resource-local JSON')
    print('[BotRP Characters] Framework dependency: none')
    print('[BotRP Characters] Initialized successfully.')
    print('========================================')
end)
