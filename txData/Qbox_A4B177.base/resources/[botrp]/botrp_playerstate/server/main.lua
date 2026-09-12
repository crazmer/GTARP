local states = {}

local function getPlayer(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function buildState(src)
    local player = getPlayer(src)
    if not player or not player.PlayerData then return nil end
    local data = player.PlayerData
    local char = data.charinfo or {}
    return {
        source = tonumber(src),
        citizenid = data.citizenid,
        license = data.license,
        name = data.name or (('%s %s'):format(char.firstname or '', char.lastname or '')),
        firstname = char.firstname,
        lastname = char.lastname,
        cid = char.cid,
        phone = char.phone,
        birthdate = char.birthdate,
        gender = char.gender,
        nationality = char.nationality,
        job = data.job,
        jobs = data.jobs,
        gang = data.gang,
        gangs = data.gangs,
        money = data.money,
        metadata = data.metadata,
        isLoggedIn = true,
    }
end

local function publish(src, reason)
    src = tonumber(src)
    local state = buildState(src)
    if not state then return nil end
    states[src] = state
    TriggerClientEvent(BotRPPlayerState.Config.events.clientReady, src, state)
    TriggerEvent(BotRPPlayerState.Config.events.ready, src, state, reason)
    return state
end

local function refresh(src, reason)
    src = tonumber(src)
    local old = states[src]
    local state = buildState(src)
    if not state then return nil end
    states[src] = state
    TriggerClientEvent(BotRPPlayerState.Config.events.clientUpdated, src, state, reason)
    TriggerEvent(BotRPPlayerState.Config.events.updated, src, state, old, reason)
    return state
end

AddEventHandler('botrp:server:playerReady', function(src)
    publish(src, 'core_ready')
end)

AddEventHandler('QBCore:Server:OnPlayerUpdated', function(src)
    src = tonumber(src)
    if states[src] then refresh(src, 'qbox_player_updated') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local state = states[src]
    if not state then return end
    states[src] = nil
    TriggerEvent(BotRPPlayerState.Config.events.left, src, state)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print(('[BotRP] playerstate v%s started'):format(BotRPPlayerState.Config.version))
    if GetResourceState('qbx_core') ~= 'started' then return end
    local players = exports.qbx_core:GetQBPlayers()
    if not players then return end
    for src in pairs(players) do publish(tonumber(src), 'resource_start') end
end)

lib.callback.register('botrp:playerstate:get', function(source)
    return states[source] or buildState(source)
end)

exports('GetState', function(src)
    src = tonumber(src)
    return states[src] or buildState(src)
end)

exports('IsReady', function(src)
    return states[tonumber(src)] ~= nil
end)

exports('GetAll', function()
    local result = {}
    for src, state in pairs(states) do result[src] = state end
    return result
end)

exports('Refresh', function(src, reason)
    return refresh(src, reason or 'manual')
end)
