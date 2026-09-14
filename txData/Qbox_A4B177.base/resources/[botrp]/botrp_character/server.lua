local deleteBusy = {}

local function getSourceLicenses(source)
    return GetPlayerIdentifierByType(source, 'license'), GetPlayerIdentifierByType(source, 'license2')
end

local function validCitizenId(citizenId)
    return type(citizenId) == 'string' and citizenId ~= '' and #citizenId <= 64
end

lib.callback.register('botrp_character:server:deleteCharacter', function(source, citizenId)
    if deleteBusy[source] or not validCitizenId(citizenId) then return false end
    if GetResourceState('qbx_core') ~= 'started' or GetResourceState('oxmysql') ~= 'started' then return false end

    local row = MySQL.single.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', { citizenId })
    if not row or not row.license then return false end

    local license, license2 = getSourceLicenses(source)
    if row.license ~= license and row.license ~= license2 then
        -- Never turn a bad ownership request into an exploit kick from the
        -- character UI. Simply refuse it; qbx_core still owns the normal
        -- anti-cheat path for character login and other privileged actions.
        return false
    end

    deleteBusy[source] = true
    exports.qbx_core:DeleteCharacter(citizenId)

    local deadline = GetGameTimer() + 5000
    local deleted = false
    while GetGameTimer() < deadline do
        local exists = MySQL.scalar.await('SELECT 1 FROM players WHERE citizenid = ? LIMIT 1', { citizenId })
        if not exists then
            deleted = true
            break
        end
        Wait(50)
    end

    deleteBusy[source] = nil
    return deleted
end)

AddEventHandler('playerDropped', function()
    deleteBusy[source] = nil
end)