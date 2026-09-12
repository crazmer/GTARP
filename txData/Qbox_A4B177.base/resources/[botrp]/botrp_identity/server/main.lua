local RESOURCE = GetCurrentResourceName()
local identities = {}
local cardEnsurePending = {}
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

local function hasIdCard(src)
    if GetResourceState('ox_inventory') ~= 'started' then return false end
    local ok, count = pcall(function() return exports.ox_inventory:Search(src, 'count', 'id_card') end)
    return ok and tonumber(count or 0) > 0
end

local function issueIdCard(src)
    src = sourceFrom(src)
    if not src or GetResourceState('ox_inventory') ~= 'started' or GetResourceState('qbx_idcard') ~= 'started' then return false end
    if hasIdCard(src) then return true end
    local ok, result = pcall(function() return exports.qbx_idcard:CreateMetaLicense(src, 'id_card') end)
    if not ok then debugPrint('Failed to issue id_card to source', src, result); return false end
    return hasIdCard(src)
end

local function ensureIdCard(src)
    src = sourceFrom(src)
    if not src or cardEnsurePending[src] then return end
    cardEnsurePending[src] = true
    CreateThread(function()
        local delays = { 0, 1500, 3500, 7500 }
        for _, delay in ipairs(delays) do
            if delay > 0 then Wait(delay) end
            if not GetPlayerName(src) then break end
            if issueIdCard(src) then debugPrint('ID card ready for source', src); break end
        end
        cardEnsurePending[src] = nil
    end)
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
    return #(GetEntityCoords(sourcePed) - GetEntityCoords(targetPed)) <= (tonumber(Config.police.maxDistance) or 4.0)
end

local function validLicenseType(licenseType)
    return type(licenseType) == 'string' and Config.licenses[licenseType] ~= nil
end

local function getLicenses(citizenid)
    local result = {}
    if not citizenid then return result end
    local rows = MySQL.query.await('SELECT license_type, status, issued_at, revoked_at FROM botrp_identity_licenses WHERE citizenid = ?', { citizenid }) or {}
    for _, row in ipairs(rows) do
        result[row.license_type] = {
            type = row.license_type,
            label = Config.licenses[row.license_type] and Config.licenses[row.license_type].label or row.license_type,
            status = row.status,
            issued_at = row.issued_at,
            revoked_at = row.revoked_at,
        }
    end
    return result
end

local function licenseList(citizenid)
    local licenses = getLicenses(citizenid)
    local result = {}
    for licenseType, definition in pairs(Config.licenses) do
        result[licenseType] = licenses[licenseType] or {
            type = licenseType,
            label = definition.label,
            status = 'not_issued',
        }
    end
    return result
end

local function verifyIdentity(src, target)
    src, target = sourceFrom(src), sourceFrom(target)
    if not src or not target or src == target then return false, 'Invalid player target.' end
    if not isPolice(src) then return false, 'You are not authorized to verify identification.' end
    if not GetPlayerName(target) then return false, 'That player is not online.' end
    if not withinDistance(src, target) then return false, 'You must be within 4 meters of the player.' end
    local identity = identities[target] or buildIdentity(target)
    if not identity then return false, 'The player identity is not ready.' end
    identity.licenses = licenseList(identity.citizenid)
    return true, identity
end

local function audit(action, source, target, metadata)
    if GetResourceState('botrp_audit') == 'started' then
        exports.botrp_audit:Log({ category = 'identity', action = action, source = source, target = target, resource = RESOURCE, message = action, metadata = metadata or {} })
    end
end

AddEventHandler(Config.coreEvents.playerReady, function(src) refresh(src) end)
AddEventHandler(Config.coreEvents.playerLeft, function(src)
    src = sourceFrom(src)
    if src then identities[src] = nil; cardEnsurePending[src] = nil end
end)
AddEventHandler('QBCore:Server:OnPlayerUpdated', function(value)
    local src = sourceFrom(value)
    if src and identities[src] then refresh(src) end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    print(('[BotRP] identity v%s started'):format(Config.version))
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS botrp_identity_licenses (
        citizenid VARCHAR(50) NOT NULL,
        license_type VARCHAR(32) NOT NULL,
        status VARCHAR(16) NOT NULL DEFAULT 'valid',
        issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        revoked_at TIMESTAMP NULL DEFAULT NULL,
        PRIMARY KEY (citizenid, license_type),
        INDEX idx_botrp_identity_licenses_citizenid (citizenid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
    if GetResourceState('qbx_core') ~= 'started' then return end
    local players = exports.qbx_core:GetQBPlayers()
    if players then for src in pairs(players) do refresh(tonumber(src)) end end
end)

lib.callback.register('botrp:identity:get', function(source)
    local identity = identities[source] or buildIdentity(source)
    if identity then identity.licenses = licenseList(identity.citizenid) end
    return identity
end)

lib.callback.register('botrp:identity:verify', function(source, target)
    local ok, result = verifyIdentity(source, target)
    if not ok then return { success = false, error = result } end
    audit('police_verification', source, target, { citizenid = result.citizenid, name = result.name })
    TriggerClientEvent(Config.events.verification, source, result)
    return { success = true, identity = result }
end)

local function modifyLicense(source, target, licenseType, action)
    target = tonumber(target)
    if source == 0 or not isPolice(source) then return false, 'You are not authorized.' end
    if not target or not GetPlayerName(target) then return false, 'That player is not online.' end
    if not validLicenseType(licenseType) then return false, 'Invalid license type.' end
    if not withinDistance(source, target) then return false, 'You must be within 4 meters of the player.' end
    local identity = identities[target] or buildIdentity(target)
    if not identity then return false, 'Player identity is not ready.' end

    if action == 'issue' then
        MySQL.query.await([[INSERT INTO botrp_identity_licenses (citizenid, license_type, status, issued_at, revoked_at)
            VALUES (?, ?, 'valid', CURRENT_TIMESTAMP, NULL)
            ON DUPLICATE KEY UPDATE status = 'valid', issued_at = CURRENT_TIMESTAMP, revoked_at = NULL]],
            { identity.citizenid, licenseType })
    else
        MySQL.update.await([[UPDATE botrp_identity_licenses SET status = 'revoked', revoked_at = CURRENT_TIMESTAMP WHERE citizenid = ? AND license_type = ?]],
            { identity.citizenid, licenseType })
    end

    audit('license_' .. action, source, target, { citizenid = identity.citizenid, license = licenseType })
    return true
end

exports('GetLicenses', function(src)
    local identity = identities[sourceFrom(src)] or buildIdentity(src)
    return identity and licenseList(identity.citizenid) or {}
end)

exports('GetLicense', function(src, licenseType)
    if not validLicenseType(licenseType) then return nil end
    local licenses = exports[RESOURCE]:GetLicenses(src)
    return licenses[licenseType]
end)

exports('IssueLicense', function(src, licenseType, officerSource)
    local officer = sourceFrom(officerSource)
    local target = sourceFrom(src)
    return modifyLicense(officer, target, licenseType, 'issue')
end)

exports('RevokeLicense', function(src, licenseType, officerSource)
    local officer = sourceFrom(officerSource)
    local target = sourceFrom(src)
    return modifyLicense(officer, target, licenseType, 'revoke')
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
    local ok, result = verifyIdentity(source, tonumber(args.id))
    if not ok then lib.notify(source, { title = 'ID Verification', description = result, type = 'error' }); return end
    audit('police_verification', source, tonumber(args.id), { citizenid = result.citizenid, name = result.name })
    TriggerClientEvent(Config.events.verification, source, result)
end)

lib.addCommand('botrp_issue_license', {
    help = 'Issue a BotRP license to a nearby player (police only)',
    params = {
        { name = 'id', type = 'number', help = 'Server ID of the player' },
        { name = 'license', type = 'string', help = 'driving, motorcycle, or weapon' },
    },
    restricted = false,
}, function(source, args)
    local ok, err = modifyLicense(source, args.id, args.license, 'issue')
    lib.notify(source, { title = 'License', description = ok and 'License issued.' or err, type = ok and 'success' or 'error' })
end)

lib.addCommand('botrp_revoke_license', {
    help = 'Revoke a BotRP license from a nearby player (police only)',
    params = {
        { name = 'id', type = 'number', help = 'Server ID of the player' },
        { name = 'license', type = 'string', help = 'driving, motorcycle, or weapon' },
    },
    restricted = false,
}, function(source, args)
    local ok, err = modifyLicense(source, args.id, args.license, 'revoke')
    lib.notify(source, { title = 'License', description = ok and 'License revoked.' or err, type = ok and 'success' or 'error' })
end)

lib.addCommand('botrp_licenses', {
    help = 'View a nearby player\'s BotRP licenses (police only)',
    params = { { name = 'id', type = 'number', help = 'Server ID of the player' } },
    restricted = false,
}, function(source, args)
    local ok, identity = verifyIdentity(source, tonumber(args.id))
    if not ok then lib.notify(source, { title = 'Licenses', description = identity, type = 'error' }); return end
    local lines = {}
    for _, licenseType in ipairs({ 'driving', 'motorcycle', 'weapon' }) do
        local license = identity.licenses[licenseType]
        lines[#lines + 1] = ('%s: %s'):format(license.label, license.status == 'valid' and 'VALID' or license.status == 'revoked' and 'REVOKED' or 'NOT ISSUED')
    end
    lib.alertDialog({ header = 'License Check', content = table.concat(lines, '\n'), centered = true, cancel = true, labels = { cancel = 'Close' } })
    audit('license_check', source, tonumber(args.id), { citizenid = identity.citizenid })
end)
