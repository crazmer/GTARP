local RESOURCE = GetCurrentResourceName()
local identities = {}
local Config = BotRPIdentity.Config

local function debugPrint(...)
    if not GetConvarInt('botrp_debug', 0) then return end
    print(('[%s]'):format(RESOURCE), ...)
end

local function sourceFrom(value)
    if type(value) == 'number' then return value end
    if type(value) == 'table' and value.PlayerData then
        return tonumber(value.PlayerData.source)
    end
    return tonumber(value)
end

local function getPlayer(src)
    src = sourceFrom(src)
    if not src or src <= 0 then return nil end
    if GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function ensureIdCard(src)
    src = sourceFrom(src)
    if not src then return false end
    if GetResourceState('ox_inventory') ~= 'started' then
        debugPrint('ox_inventory is not started; cannot issue id_card to', src)
        return false
    end
    if GetResourceState('qbx_idcard') ~= 'started' then
        debugPrint('qbx_idcard is not started; cannot issue id_card to', src)
        return false
    end

    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', 'id_card')
    end)

    if ok and tonumber(count or 0) > 0 then
        return true
    end

    -- qbx_idcard already owns the correct metadata format and item registration.
    -- Use its official helper instead of constructing an incompatible metadata object.
    local added, result = pcall(function()
        return exports.qbx_idcard:CreateMetaLicense(src, {'id_card'})
    end)

    if not added then
        debugPrint('Failed to issue id_card to source', src, result)
        return false
    end

    debugPrint('Issued identification card to source', src)
    return true
end

local function buildIdentity(src)
    src = sourceFrom(src)
    local player = getPlayer(src)
    if not player or not player.PlayerData then return nil end

    local data = player.PlayerData
    local char = data.charinfo or {}
    local firstname = tostring(char.firstname or '')
    local lastname = tostring(char.lastname or '')

    return {
        source = src,
        citizenid = data.citizenid,
        license = data.license,
        cid = char.cid,
        name = data.name or (('%s %s'):format(firstname, lastname)):gsub('^%s*(.-)%s*$', '%1'),
        firstname = firstname,
        lastname = lastname,
        birthdate = char.birthdate,
        gender = char.gender,
        nationality = char.nationality,
        phone = char.phone,
    }
end

local function refresh(src)
    src = sourceFrom(src)
    if not src then return nil end

    local identity = buildIdentity(src)
    if not identity then
        identities[src] = nil
        return nil
    end

    identities[src] = identity
    ensureIdCard(src)
    TriggerClientEvent(Config.events.updated, src, identity)
    TriggerEvent(Config.events.ready, src, identity)
    return identity
end

local function handlePlayerUpdate(value)
    local src = sourceFrom(value)
    if src and identities[src] then
        refresh(src)
    end
end

AddEventHandler(Config.coreEvents.playerReady, function(src)
    refresh(src)
end)

AddEventHandler(Config.coreEvents.playerLeft, function(src)
    src = sourceFrom(src)
    if src then identities[src] = nil end
end)

AddEventHandler('QBCore:Server:OnPlayerUpdated', handlePlayerUpdate)

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
    src = sourceFrom(src)
    return identities[src] or buildIdentity(src)
end)

exports('GetIdentities', function()
    local result = {}
    for src, identity in pairs(identities) do
        result[src] = identity
    end
    return result
end)

exports('GetIdentityField', function(src, field)
    if type(field) ~= 'string' then return nil end
    local identity = identities[sourceFrom(src)] or buildIdentity(src)
    return identity and identity[field] or nil
end)

exports('Refresh', function(src)
    return refresh(src)
end)

exports('IsLoaded', function(src)
    return identities[sourceFrom(src)] ~= nil
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

    ensureIdCard(source)

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
