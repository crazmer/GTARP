local identity = nil

local function isPolice()
    if GetResourceState('qbx_core') ~= 'started' then return false end
    local playerData = exports.qbx_core:GetPlayerData()
    local job = playerData and playerData.job
    return job and BotRPIdentity.Config.police.jobs[job.name] == true or false
end

local function licenseStatus(license)
    if not license or license.status == 'not_issued' then return 'NOT ISSUED' end
    if license.status == 'revoked' then return 'REVOKED' end
    return 'VALID'
end

local function showIdentity(data)
    if not data then
        lib.notify({ title = 'ID Verification', description = 'No identity information was returned.', type = 'error' })
        return
    end

    local gender = data.gender
    if gender == 0 then gender = 'Male'
    elseif gender == 1 then gender = 'Female'
    else gender = tostring(gender or 'Unknown') end

    local lines = {
        ('Name: %s'):format(data.name or 'Unknown'),
        ('Citizen ID: %s'):format(data.citizenid or 'Unknown'),
        ('DOB: %s'):format(data.birthdate or 'Unknown'),
        ('Gender: %s'):format(gender),
        ('Nationality: %s'):format(data.nationality or 'Unknown'),
        ('Phone: %s'):format(data.phone or 'Unknown'),
    }

    if data.licenses then
        lines[#lines + 1] = ''
        lines[#lines + 1] = '--- LICENSES ---'
        for _, licenseType in ipairs({ 'driving', 'motorcycle', 'weapon' }) do
            local license = data.licenses[licenseType]
            if license then lines[#lines + 1] = ('%s: %s'):format(license.label, licenseStatus(license)) end
        end
    end

    lib.alertDialog({ header = 'Identity Verification', content = table.concat(lines, '\n'), centered = true, cancel = true, labels = { cancel = 'Close' } })
end

RegisterNetEvent(BotRPIdentity.Config.events.updated, function(data)
    identity = data
end)

RegisterNetEvent(BotRPIdentity.Config.events.verification, function(data)
    showIdentity(data)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    identity = nil
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    identity = lib.callback.await('botrp:identity:get', false)
end)

exports('GetIdentity', function() return identity end)
exports('IsLoaded', function() return identity ~= nil end)
exports('GetVersion', function() return BotRPIdentity.Config.version end)

CreateThread(function()
    Wait(1500)
    if GetResourceState('qbx_core') ~= 'started' then return end
    identity = lib.callback.await('botrp:identity:get', false)

    while GetResourceState('ox_target') ~= 'started' do Wait(1000) end

    exports.ox_target:addGlobalPlayer({
        {
            name = 'botrp_identity_check_id',
            icon = 'fa-solid fa-id-card',
            label = 'Check ID',
            distance = BotRPIdentity.Config.police.maxDistance or 4.0,
            canInteract = function(entity)
                return isPolice() and entity ~= PlayerPedId()
            end,
            onSelect = function(data)
                local playerIndex = NetworkGetPlayerIndexFromPed(data.entity)
                if playerIndex == -1 then
                    lib.notify({ title = 'ID Verification', description = 'Could not identify that player.', type = 'error' })
                    return
                end

                local target = GetPlayerServerId(playerIndex)
                local result = lib.callback.await('botrp:identity:verify', false, target)
                if not result or not result.success then
                    lib.notify({ title = 'ID Verification', description = result and result.error or 'Verification failed.', type = 'error' })
                    return
                end
                showIdentity(result.identity)
            end,
        },
    })
end)
