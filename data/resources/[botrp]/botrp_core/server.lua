local sessions = {}

local function log(message)
    print(('[BotRP Core] %s'):format(message))
end

local function createSession(source)
    local identifier = exports.botrp_bridge:GetIdentifier(source)

    sessions[source] = {
        source = source,
        identifier = identifier,
        connectedAt = os.time()
    }

    TriggerClientEvent('botrp:core:sessionReady', source, {
        identifier = identifier
    })

    log(('Session created: %s (%s)'):format(GetPlayerName(source) or 'Unknown', identifier))
end

local function destroySession(source)
    local session = sessions[source]

    if session then
        log(('Session closed: %s (%s)'):format(GetPlayerName(source) or 'Unknown', session.identifier))
    end

    sessions[source] = nil
end

AddEventHandler('playerJoining', function()
    local source = source

    SetTimeout(500, function()
        if GetPlayerName(source) then
            createSession(source)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    destroySession(source)
end)

exports('GetSession', function(source)
    return sessions[source]
end)

exports('GetIdentifier', function(source)
    local session = sessions[source]
    if session then return session.identifier end
    return exports.botrp_bridge:GetIdentifier(source)
end)

CreateThread(function()
    print('========================================')
    print('          BotRP Core Initialized')
    print('========================================')
    print(('[BotRP Core] Version: %s'):format(BotRPConfig.Version))
    print('[BotRP Core] Framework: standalone API')
    print('[BotRP Core] Character system: external resource')
    print('[BotRP Core] Storage: external resource')
    print('[BotRP Core] QBCore/Qbox: adapter-compatible')
    print('[BotRP Core] Initialized successfully.')
    print('========================================')
end)
