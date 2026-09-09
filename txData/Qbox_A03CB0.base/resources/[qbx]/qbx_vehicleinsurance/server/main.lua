local RESOURCE = GetCurrentResourceName()
local INSURANCE_DAYS = 30
local INSURANCE_COST = 500

local function trimPlate(plate)
    return qbx.string.trim(plate or ''):upper()
end

local function getCitizenId(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid
end

local function getVehicleForOwner(source, plate)
    local citizenid = getCitizenId(source)
    if not citizenid then return end

    plate = trimPlate(plate)
    if plate == '' then return end

    return MySQL.single.await([[SELECT id, citizenid, vehicle, plate, state, garage
        FROM player_vehicles
        WHERE citizenid = ? AND plate = ? LIMIT 1]], { citizenid, plate })
end

local function ensureTable()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS vehicle_insurance (
        vehicle_id INT NOT NULL,
        insured TINYINT(1) NOT NULL DEFAULT 1,
        stolen TINYINT(1) NOT NULL DEFAULT 0,
        expires_at DATETIME NULL,
        PRIMARY KEY (vehicle_id),
        CONSTRAINT fk_vehicle_insurance_vehicle
            FOREIGN KEY (vehicle_id) REFERENCES player_vehicles(id)
            ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function ensureVehicleRecord(vehicleId)
    local record = MySQL.single.await('SELECT vehicle_id, insured, stolen, expires_at FROM vehicle_insurance WHERE vehicle_id = ? LIMIT 1', { vehicleId })
    if record then return record end

    local expiresAt = os.date('!%Y-%m-%d %H:%M:%S', os.time() + INSURANCE_DAYS * 86400)
    MySQL.insert.await('INSERT IGNORE INTO vehicle_insurance (vehicle_id, insured, stolen, expires_at) VALUES (?, 1, 0, ?)', { vehicleId, expiresAt })
    return MySQL.single.await('SELECT vehicle_id, insured, stolen, expires_at FROM vehicle_insurance WHERE vehicle_id = ? LIMIT 1', { vehicleId })
end

local function isInsuranceActive(record)
    if not record or not record.insured or not record.expires_at then return false end
    return tostring(record.expires_at) > os.date('!%Y-%m-%d %H:%M:%S')
end

local function notify(source, message, kind)
    exports.qbx_core:Notify(source, message, kind or 'inform')
end

RegisterCommand('vehiclestatus', function(source, args)
    if source == 0 then return end

    local vehicle = getVehicleForOwner(source, args[1])
    if not vehicle then
        notify(source, 'Vehicle not found or it is not registered to you.', 'error')
        return
    end

    local insurance = ensureVehicleRecord(vehicle.id)
    local active = isInsuranceActive(insurance)
    local expires = insurance and insurance.expires_at or 'Unknown'
    local stolen = insurance and insurance.stolen == 1

    notify(source, ('%s [%s] | Registration: VALID | Insurance: %s | Expires: %s | Stolen: %s'):format(
        vehicle.vehicle,
        vehicle.plate,
        active and 'ACTIVE' or 'EXPIRED',
        expires,
        stolen and 'YES' or 'NO'
    ))
end, false)

RegisterCommand('renewinsurance', function(source, args)
    if source == 0 then return end

    local vehicle = getVehicleForOwner(source, args[1])
    if not vehicle then
        notify(source, 'Vehicle not found or it is not registered to you.', 'error')
        return
    end

    local insurance = ensureVehicleRecord(vehicle.id)
    if isInsuranceActive(insurance) then
        notify(source, 'This vehicle already has active insurance.', 'error')
        return
    end

    local player = exports.qbx_core:GetPlayer(source)
    if not player or not player.Functions.RemoveMoney('bank', INSURANCE_COST, 'vehicle-insurance') then
        notify(source, ('You need $%s in your bank account.'):format(INSURANCE_COST), 'error')
        return
    end

    local expiresAt = os.date('!%Y-%m-%d %H:%M:%S', os.time() + INSURANCE_DAYS * 86400)
    MySQL.update.await('UPDATE vehicle_insurance SET insured = 1, stolen = 0, expires_at = ? WHERE vehicle_id = ?', { expiresAt, vehicle.id })
    notify(source, ('Insurance renewed for %d days.'):format(INSURANCE_DAYS), 'success')
end, false)

RegisterCommand('reportstolen', function(source, args)
    if source == 0 then return end

    local vehicle = getVehicleForOwner(source, args[1])
    if not vehicle then
        notify(source, 'Vehicle not found or it is not registered to you.', 'error')
        return
    end

    ensureVehicleRecord(vehicle.id)
    MySQL.update.await('UPDATE vehicle_insurance SET stolen = 1 WHERE vehicle_id = ?', { vehicle.id })
    notify(source, ('Vehicle %s has been reported stolen.'):format(vehicle.plate), 'success')
end, false)

RegisterCommand('recovervehicle', function(source, args)
    if source == 0 then return end

    local vehicle = getVehicleForOwner(source, args[1])
    if not vehicle then
        notify(source, 'Vehicle not found or it is not registered to you.', 'error')
        return
    end

    local insurance = ensureVehicleRecord(vehicle.id)
    if not insurance or insurance.stolen ~= 1 then
        notify(source, 'This vehicle is not marked as stolen.', 'error')
        return
    end

    MySQL.update.await('UPDATE vehicle_insurance SET stolen = 0 WHERE vehicle_id = ?', { vehicle.id })
    notify(source, ('Vehicle %s is no longer marked as stolen.'):format(vehicle.plate), 'success')
end, false)

exports('GetVehicleInsurance', function(vehicleId)
    local record = ensureVehicleRecord(vehicleId)
    if not record then return nil end
    return {
        insured = record.insured == 1 and isInsuranceActive(record),
        stolen = record.stolen == 1,
        expiresAt = record.expires_at
    }
end)

CreateThread(function()
    ensureTable()
    print(('[%s] Vehicle registration and insurance system started.'):format(RESOURCE))
end)
