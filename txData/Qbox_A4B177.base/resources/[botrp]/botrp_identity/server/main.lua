local RESOURCE = GetCurrentResourceName()
local identities = {}
local Config = BotRPIdentity.Config

local function debugPrint(...)
    if not GetConvarInt('botrp_debug', 0) then return end
    print(('[%s]'):format(RESOURCE), ...)
end

local function getPlayer(src)
    if not src or src <= 0 then return nil end
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function buildIdentity(src)
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
        birthdate = char.birthdate,
        gender = char.gender,
        nationality = char.nationality,
        phone = char.phone,
        cid = char.cid,
    }
end

local function refresh(src)
    local identity = buildIdentity(src)
    if not identity then
        identities[src] = nil
        return nil
    end

    identities[src] = identity
    TriggerClientEvent(Config.events.updated, src, identity)
    TriggerEvent(Config.events.ready, src, identity)
    return identity
end

AddEventHandler(Config.coreEvents.playerReady, function(src)
    refresh(tonumber(src))
end)

AddEventHandler(Config.coreEvents.playerLeft, function(src)
    identities[tonumber(src)] = nil
end)

AddEventHandler('QBCore:Server:OnPlayerUpdated', function(src)
    if identities[tonumber(src)] then
        refresh(tonumber(src))
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end

    print(('[BotRP] identity v%s started'):format(Config.version))

    if GetResourceState('qbx_core') ~= 'started' then return end
    local players = exports.qbx_core:GetQBPlayers()
    if not players then return end

    for src in pairs(players) do
        refresh(tonumber(src))
    end
end)

lib.callback.register('botrp:identity:get', function(source)
    return identities[source] or buildIdentity(source)
end)

exports('GetIdentity', function(src)
    src = tonumber(src)
    return identities[src] or buildIdentity(src)
end)

exports('GetIdentities', function()
    local result = {}
    for src, identity in pairs(identities) do
        result[src] = identity
    end
    return result
end)

exports('IsLoaded', function(src)
    return identities[tonumber(src)] ~= nil
end)

exports('GetVersion', function()
    return Config.version
end)

lib.addCommand('botrp_identity', {
    help = 'Print your BotRP identity information',
    restricted = false,
}, function(source)
    if source == 0 then return end

    local identity = identities[source] or buildIdentity(source)
    if not identity then
        lib.notify(source, {
            title = 'BotRP Identity',
            description = 'Character identity is not ready.',
            type = 'error',
        })
        return
    end

    lib.notify(source, {
        title = 'BotRP Identity',
        description = ('%s %s | CID: %s | Citizen ID: %s'):format(
            identity.firstname or '',
            identity.lastname or '',
            identity.cid or '?',
            identity.citizenid or '?'
        ),
        type = 'inform',
    })

    debugPrint('Identity requested:', source, identity.citizenid)
end)
