local RESOURCE = GetCurrentResourceName()
local identities = {}
local Config = BotRPIdentity.Config

local function debugPrint(...)
    if not GetConvarInt('botrp_debug', 0) then return end
    print(('[%s]'):format(RESOURCE), ...)
end

local function sourceFrom(value)
    if type(value) == 'number' then return value end
    if type(value) == 'table' and value.PlayerData then return tonumber(value.PlayerData.source) end
    return tonumber(value)
end

local function getPlayer(src)
    src = sourceFrom(src)
    if not src or src <= 0 or GetResourceState('qbx_core') ~= 'started' then return nil end
    return exports.qbx_core:GetPlayer(src)
end

local function ensureIdCard(src)
    src = sourceFrom(src)
    if not src or GetResourceState('ox_inventory') ~= 'started' or GetResourceState('qbx_idcard') ~= 'started' then return false end
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', 'id_card') end)
    if ok and tonumber(count or 0) > 0 then return true end
    local added = pcall(function() return exports.qbx_idcard:CreateMetaLicense(src, {'id_card'}) end)
    if not added then debugPrint('Failed to issue id_card to source', src); return false end
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
        source = src, citizenid = data.citizenid, license = data.license, cid = char.cid,
        name = data.name or (('%s %s'):format(firstname, lastname)):gsub('^%s*(.-)%s*$', '%1'),
        firstname = firstname, lastname = lastname, birthdate = char.birthdate,
        gender = char.gender, nationality = char.nationality, phone = char.phone,
    }
end

local function refresh(src)
    src = sourceFrom(src)
    if not src then return nil end
    local identity = buildIdentity(src)
    if not identity then identities[src] = nil; return nil end
    identities[src] = identity
    ensureIdCard(src)
    TriggerClientEvent(Config.events.updated, src, identity)
    TriggerEvent(Config.events.ready, src, identity)
    return identity
end

local function isPolice(src)
    local player = getPlayer(src)
    if not player or not player.PlayerData then return false end
    local job = player.PlayerData.job
    if not job or not Config.police.jobs[job.name] then return false end
    local requiredGrade = Config.police.grades[job.name]
    if requiredGrade ~= nil then
        local level = type(job.grade) == 'table' and job.grade.level or tonumber(job.grade)
        if not level or level < requiredGrade then return false end
    end
    return true
end

local function withinDistance(src, target)
    local sourcePed, targetPed = GetPlayerPed(src), GetPlayerPed(target)
    if sourcePed == 0 or targetPed == 0 then return false end
    local sourceCoords, targetCoords = GetEntityCoords(sourcePed), GetEntityCoords(targetPed)
    return #(sourceCoords - targetCoords) <= (tonumber(Config.police.maxDistance) or 4.0)
end

local function verifyIdentity(src, target)
    src, target = sourceFrom(src), sourceFrom(target)
    if not src or not target or src == target then return false, 'Invalid player target.' end
    if not isPolice(src) then return false, 'You are not authorized to verify identification.' end
    if not GetPlayerName(target) then return false, 'That player is not online.' end
    if not withinDistance(src, target) then return false, 'You must be within 4 meters of the player.' end
    local identity = identities[target] or buildIdentity(target)
    if not identity then return false, 'The player identity is not ready.' end
    return true, identity
end

AddEventHandler(Config.coreEvents.playerReady, function(src) refresh(src) end)
AddEventHandler(Config.coreEvents.playerLeft, function(src)
    src = sourceFrom(src)
    if src then identities[src] = nil end
end)
AddEventHandler('QBCore:Server:OnPlayerUpdated', function(value)
    local src = sourceFrom(value)
    if src and identities[src] then refresh(src) end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    print(('[BotRP] identity v%s started'):format(Config.version))
    if GetResourceState('qbx_core') ~= 'started' then return end
    local players = exports.qbx_core:GetQBPlayers()
    if players then for src in pairs(players) do refresh(tonumber(src)) end end
end)

lib.callback.register('botrp:identity:get', function(source)
    return identities[source] or buildIdentity(source)
end)

lib.callback.register('botrp:identity:verify', function(source, target)
    local ok, result = verifyIdentity(source, target)
    if not ok then return { success = false, error = result } end
    if GetResourceState('botrp_audit') == 'started' then
        exports.botrp_audit:Log({
            category = 'identity', action = 'police_verification', source = source, target = target,
            resource = RESOURCE, message = 'Police identity verification',
            metadata = { citizenid = result.citizenid, name = result.name },
        })
    end
    TriggerClientEvent(Config.events.verification, source, result)
    return { success = true, identity = result }
end)

exports('GetIdentity', function(src) src = sourceFrom(src); return identities[src] or buildIdentity(src) end)
exports('GetIdentities', function() local result = {}; for src, identity in pairs(identities) do result[src] = identity end; return result end)
exports('GetIdentityField', function(src, field)
    if type(field) ~= 'string' then return nil end
    local identity = identities[sourceFrom(src)] or buildIdentity(src)
    return identity and identity[field] or nil
end)
exports('Refresh', function(src) return refresh(src) end)
exports('IsLoaded', function(src) return identities[sourceFrom(src)] ~= nil end)
exports('GetVersion', function() return Config.version end)

lib.addCommand('botrp_identity', { help = 'Print your BotRP identity information', restricted = false }, function(source)
    if source == 0 then return end
    local identity = identities[source] or buildIdentity(source)
    if not identity then
        lib.notify(source, { title = 'BotRP Identity', description = 'Character identity is not ready.', type = 'error' })
        return
    end
    ensureIdCard(source)
    lib.notify(source, { title = 'BotRP Identity', description = ('%s %s | CID: %s | Citizen ID: %s'):format(identity.firstname or '', identity.lastname or '', identity.cid or '?', identity.citizenid or '?'), type = 'inform' })
end)

lib.addCommand('botrp_verifyid', {
    help = 'Verify a nearby player identity (police only)',
    params = { { name = 'id', type = 'number', help = 'Server ID of the player' } },
    restricted = false,
}, function(source, args)
    if source == 0 then return end
    local target = tonumber(args.id)
    local ok, result = verifyIdentity(source, target)
    if not ok then
        lib.notify(source, { title = 'ID Verification', description = result, type = 'error' })
        return
    end
    if GetResourceState('botrp_audit') == 'started' then
        exports.botrp_audit:Log({ category = 'identity', action = 'police_verification', source = source, target = target, resource = RESOURCE, message = 'Police identity verification', metadata = { citizenid = result.citizenid, name = result.name } })
    end
    TriggerClientEvent(Config.events.verification, source, result)
end)
