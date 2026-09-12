local resourceName = GetCurrentResourceName()

local function now()
    return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function safeSource(source)
    source = tonumber(source)
    if source and source > 0 then return source end
    return nil
end

local function normalize(data)
    data = data or {}
    return {
        id = ('%s-%d-%04d'):format(os.date('!%Y%m%d%H%M%S'), os.time() % 10000, math.random(0, 9999)),
        timestamp = now(),
        category = tostring(data.category or 'system'),
        action = tostring(data.action or 'event'),
        source = safeSource(data.source),
        target = safeSource(data.target),
        resource = tostring(data.resource or resourceName),
        message = data.message and tostring(data.message) or nil,
        metadata = type(data.metadata) == 'table' and data.metadata or {},
    }
end

local function writeLog(entry)
    if not BotRP_Audit.enabled then return false end
    if BotRP_Audit.categories[entry.category] == false then return false end

    local line = json.encode(entry)
    if BotRP_Audit.console then
        print(('[BotRP Audit] %s'):format(line))
    end

    if BotRP_Audit.webhook.enabled and BotRP_Audit.webhook.url ~= '' then
        PerformHttpRequest(BotRP_Audit.webhook.url, function() end, 'POST', json.encode({
            username = BotRP_Audit.webhook.username,
            content = ('```json\n%s\n```'):format(line),
        }), { ['Content-Type'] = 'application/json' })
    end

    return true
end

exports('Log', function(data)
    return writeLog(normalize(data))
end)

exports('IsEnabled', function(category)
    if not BotRP_Audit.enabled then return false end
    return category == nil or BotRP_Audit.categories[category] ~= false
end)

AddEventHandler('playerJoining', function()
    local src = source
    writeLog(normalize({
        category = 'player',
        action = 'joining',
        source = src,
        message = 'Player connection started',
    }))
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    writeLog(normalize({
        category = 'player',
        action = 'dropped',
        source = src,
        message = reason or 'Player disconnected',
    }))
end)

AddEventHandler('onResourceStart', function(res)
    writeLog(normalize({
        category = 'resource',
        action = 'started',
        resource = res,
    }))
end)

AddEventHandler('onResourceStop', function(res)
    if res == resourceName then return end
    writeLog(normalize({
        category = 'resource',
        action = 'stopped',
        resource = res,
    }))
end)

RegisterCommand('botrp_audit_test', function(source)
    if source ~= 0 then return end
    writeLog(normalize({
        category = 'system',
        action = 'test',
        message = 'BotRP audit test event',
        metadata = { status = 'ok' },
    }))
end, true)

print(('[BotRP Audit] %s started'):format(resourceName))
