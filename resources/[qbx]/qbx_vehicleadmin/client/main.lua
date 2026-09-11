local open = false

local function closePanel()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterCommand('vehicleadmin', function()
    lib.callback('qbx_vehicleadmin:server:open', false, function(allowed)
        if not allowed then
            lib.notify({ description = 'You do not have permission to use the vehicle admin panel.', type = 'error' })
            return
        end
        open = true
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
    end)
end, false)

RegisterKeyMapping('vehicleadmin', 'Open vehicle admin panel', 'keyboard', 'F10')

RegisterNUICallback('close', function(_, cb)
    closePanel()
    cb(true)
end)

RegisterNUICallback('search', function(data, cb)
    lib.callback('qbx_vehicleadmin:server:search', false, function(rows)
        cb(rows or {})
    end, data.query or '')
end)

RegisterNUICallback('setState', function(data, cb)
    TriggerServerEvent('qbx_vehicleadmin:server:setState', data.id, data.state)
    cb(true)
end)

RegisterNUICallback('setGarage', function(data, cb)
    TriggerServerEvent('qbx_vehicleadmin:server:setGarage', data.id, data.garage)
    cb(true)
end)

RegisterNUICallback('delete', function(data, cb)
    TriggerServerEvent('qbx_vehicleadmin:server:delete', data.id)
    cb(true)
end)

RegisterNUICallback('get', function(data, cb)
    lib.callback('qbx_vehicleadmin:server:get', false, function(row)
        cb(row or {})
    end, data.id)
end)

RegisterNUICallback('ready', function(_, cb)
    cb(true)
end)

CreateThread(function()
    while true do
        Wait(0)
        if open and IsControlJustReleased(0, 322) then
            closePanel()
        end
    end
end)
