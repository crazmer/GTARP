local function isAdmin(source)
    return source > 0 and IsPlayerAceAllowed(source, 'group.admin')
end

local function notify(source, message, kind)
    exports.qbx_core:Notify(source, message, kind or 'inform')
end

local function getVehicle(id)
    return MySQL.single.await([[SELECT id, citizenid, vehicle, plate, garage, state, depotprice
        FROM player_vehicles WHERE id = ? LIMIT 1]], { id })
end

lib.callback.register('qbx_vehicleadmin:server:open', function(source)
    if not isAdmin(source) then return false end
    return true
end)

lib.callback.register('qbx_vehicleadmin:server:search', function(source, query)
    if not isAdmin(source) then return {} end
    query = tostring(query or '')
    if #query < 2 then return {} end

    local like = '%' .. query .. '%'
    return MySQL.query.await([[SELECT id, citizenid, vehicle, plate, garage, state, depotprice
        FROM player_vehicles
        WHERE plate LIKE ? OR citizenid LIKE ? OR vehicle LIKE ?
        ORDER BY id DESC LIMIT 50]], { like, like, like })
end)

lib.callback.register('qbx_vehicleadmin:server:get', function(source, vehicleId)
    if not isAdmin(source) then return false end
    return getVehicle(tonumber(vehicleId))
end)

RegisterNetEvent('qbx_vehicleadmin:server:setState', function(vehicleId, state)
    local source = source
    if not isAdmin(source) then return end
    vehicleId, state = tonumber(vehicleId), tonumber(state)
    if not vehicleId or not state or state < 0 or state > 2 or not getVehicle(vehicleId) then
        notify(source, 'Invalid vehicle or state.', 'error')
        return
    end
    MySQL.update.await('UPDATE player_vehicles SET state = ? WHERE id = ?', { state, vehicleId })
    notify(source, 'Vehicle state updated.', 'success')
end)

RegisterNetEvent('qbx_vehicleadmin:server:setGarage', function(vehicleId, garage)
    local source = source
    if not isAdmin(source) then return end
    vehicleId = tonumber(vehicleId)
    garage = tostring(garage or '')
    if not vehicleId or garage == '' or #garage > 64 or not getVehicle(vehicleId) then
        notify(source, 'Invalid vehicle or garage.', 'error')
        return
    end
    MySQL.update.await('UPDATE player_vehicles SET garage = ? WHERE id = ?', { garage, vehicleId })
    notify(source, 'Vehicle garage updated.', 'success')
end)

RegisterNetEvent('qbx_vehicleadmin:server:delete', function(vehicleId)
    local source = source
    if not isAdmin(source) then return end
    vehicleId = tonumber(vehicleId)
    if not vehicleId or not getVehicle(vehicleId) then
        notify(source, 'Vehicle not found.', 'error')
        return
    end
    MySQL.update.await('DELETE FROM player_vehicles WHERE id = ?', { vehicleId })
    notify(source, 'Vehicle deleted.', 'success')
end)
