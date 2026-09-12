local RESOURCE = GetCurrentResourceName()
local readyPlayers = {}

local function debugPrint(...)
    if not BotRP.Config.debug then return end
    print(('[%s]'):format(RESOURCE), ...)
end

local function getPlayer(src)
    if not src or src <= 0 then return nil end
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function buildPlayerContext(src)
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
        phone = char.phone,
        cid = char.cid,
        job = data.job,
        jobs = data.jobs,
        gang = data.gang,
        gangs = data.gangs,
    }
end

local function markReady(src)
    local context = buildPlayerContext(src)
    if not context then
        debugPrint('Player ready skipped; Qbox player not available:', src)
        return false
    end

    readyPlayers[src] = context
    TriggerClientEvent(BotRP.Config.events.playerReadyClient, src, context)
    TriggerEvent(BotRP.Config.events.playerReady, src, context)
    debugPrint('Player ready:', src, context.citizenid)
    return true
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(player)
    local src = type(player) == 'table'
        and player.PlayerData
        and player.PlayerData.source
        or source

    if src then
        markReady(tonumber(src))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if readyPlayers[src] then
        TriggerEvent(BotRP.Config.events.playerLeft, src, readyPlayers[src])
        readyPlayers[src] = nil
        debugPrint('Player left:', src)
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end

    print(('[BotRP] core v%s started'):format(BotRP.Config.resourceVersion))

    if GetResourceState('qbx_core') ~= 'started' then return end
    local players = exports.qbx_core:GetQBPlayers()
    if not players then return end

    for src in pairs(players) do
        markReady(tonumber(src))
    end
end)

lib.callback.register('botrp:server:getPlayerContext', function(source)
    return readyPlayers[source] or buildPlayerContext(source)
end)

exports('GetPlayerContext', function(src)
    return readyPlayers[tonumber(src)] or buildPlayerContext(tonumber(src))
end)

exports('IsPlayerReady', function(src)
    return readyPlayers[tonumber(src)] ~= nil
end)

exports('GetReadyPlayers', function()
    local result = {}
    for src, context in pairs(readyPlayers) do
        result[src] = context
    end
    return result
end)

exports('GetVersion', function()
    return BotRP.Config.resourceVersion
end)
