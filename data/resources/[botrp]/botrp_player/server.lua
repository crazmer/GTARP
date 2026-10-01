local playerStates = {}

local function clone(value)
    if type(value) ~= 'table' then return value end

    local result = {}
    for key, item in pairs(value) do
        result[key] = clone(item)
    end

    return result
end

local function getIdentifier(source)
    return exports.botrp_core:GetIdentifier(source)
end

local function ensureState(source)
    if playerStates[source] then
        return playerStates[source]
    end

    local identifier = getIdentifier(source)

    playerStates[source] = {
        source = source,
        identifier = identifier,
        characterId = nil,
        money = clone(BotRPPlayerConfig.Defaults.money),
        metadata = clone(BotRPPlayerConfig.Defaults.metadata),
        permissions = clone(BotRPPlayerConfig.Defaults.permissions),
        loaded = true
    }

    return playerStates[source]
end

local function sanitizePatch(patch)
    if type(patch) ~= 'table' then return nil end

    local result = {}

    if type(patch.characterId) == 'number' then
        result.characterId = math.floor(patch.characterId)
    end

    if type(patch.money) == 'table' then
        result.money = {}
        for key, value in pairs(patch.money) do
            if (key == 'cash' or key == 'bank') and type(value) == 'number' then
                result.money[key] = math.max(0, math.floor(value))
            end
        end
    end

    if type(patch.metadata) == 'table' then
        result.metadata = {}
        for key, value in pairs(patch.metadata) do
            if type(key) == 'string' and #key <= 32 then
                if type(value) == 'number' or type(value) == 'string' or type(value) == 'boolean' then
                    result.metadata[key] = value
                end
            end
        end
    end

    if type(patch.permissions) == 'table' and type(patch.permissions.group) == 'string' then
        result.permissions = {
            group = patch.permissions.group
        }
    end

    return result
end

local function applyPatch(state, patch)
    if patch.characterId ~= nil then
        state.characterId = patch.characterId
    end

    if patch.money then
        for key, value in pairs(patch.money) do
            state.money[key] = value
        end
    end

    if patch.metadata then
        for key, value in pairs(patch.metadata) do
            state.metadata[key] = value
        end
    end

    if patch.permissions then
        state.permissions.group = patch.permissions.group
    end
end

local function publicState(state)
    return clone(state)
end

exports('GetState', function(source)
    return playerStates[source] and publicState(playerStates[source]) or nil
end)

exports('GetCharacterId', function(source)
    return playerStates[source] and playerStates[source].characterId or nil
end)

exports('SetCharacterId', function(source, characterId)
    if type(characterId) ~= 'number' then return false end

    local state = ensureState(source)
    state.characterId = math.floor(characterId)

    TriggerClientEvent('botrp:player:stateChanged', source, publicState(state))
    return true
end)

exports('GetMoney', function(source, moneyType)
    local state = playerStates[source]
    if not state then return 0 end

    return state.money[moneyType] or 0
end)

exports('AddMoney', function(source, moneyType, amount)
    if moneyType ~= 'cash' and moneyType ~= 'bank' then return false end
    if type(amount) ~= 'number' or amount < 0 then return false end

    local state = ensureState(source)
    state.money[moneyType] = state.money[moneyType] + math.floor(amount)

    TriggerClientEvent('botrp:player:stateChanged', source, publicState(state))
    return true
end)

exports('RemoveMoney', function(source, moneyType, amount)
    if moneyType ~= 'cash' and moneyType ~= 'bank' then return false end
    if type(amount) ~= 'number' or amount < 0 then return false end

    local state = ensureState(source)
    amount = math.floor(amount)

    if state.money[moneyType] < amount then
        return false
    end

    state.money[moneyType] = state.money[moneyType] - amount

    TriggerClientEvent('botrp:player:stateChanged', source, publicState(state))
    return true
end)

exports('GetMetadata', function(source, key)
    local state = playerStates[source]
    if not state then return nil end
    return state.metadata[key]
end)

exports('SetMetadata', function(source, key, value)
    if type(key) ~= 'string' or #key > 32 then return false end
    if type(value) ~= 'number' and type(value) ~= 'string' and type(value) ~= 'boolean' then
        return false
    end

    local state = ensureState(source)
    state.metadata[key] = value

    TriggerClientEvent('botrp:player:stateChanged', source, publicState(state))
    return true
end)

exports('GetPermissionGroup', function(source)
    local state = playerStates[source]
    return state and state.permissions.group or 'user'
end)

RegisterNetEvent('botrp:player:requestState', function()
    local source = source
    TriggerClientEvent('botrp:player:stateChanged', source, publicState(ensureState(source)))
end)

RegisterNetEvent('botrp:player:setCharacter', function(characterId)
    local source = source
    if type(characterId) ~= 'number' then return end

    local state = ensureState(source)
    state.characterId = math.floor(characterId)

    TriggerClientEvent('botrp:player:stateChanged', source, publicState(state))
end)

AddEventHandler('botrp:characters:selected', function()
    -- Character selection is intentionally owned by botrp_characters.
    -- This resource exposes SetCharacterId for explicit integration.
end)

AddEventHandler('playerJoining', function()
    local source = source

    SetTimeout(750, function()
        if GetPlayerName(source) then
            ensureState(source)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    playerStates[source] = nil
end)

CreateThread(function()
    print('========================================')
    print('          BotRP Player Initialized')
    print('========================================')
    print(('[BotRP Player] Version: %s'):format(BotRPPlayerConfig.Version))
    print('[BotRP Player] Persistence: memory only')
    print('[BotRP Player] Framework dependency: none')
    print('[BotRP Player] Initialized successfully.')
    print('========================================')
end)
