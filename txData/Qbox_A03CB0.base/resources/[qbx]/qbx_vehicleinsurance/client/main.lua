RegisterCommand('vehiclestatus', function(_, args)
    local plate = args[1]

    if not plate then
        local vehicle = cache.vehicle
        if vehicle and vehicle ~= 0 then
            plate = GetVehicleNumberPlateText(vehicle)
        end
    end

    if not plate or plate:gsub('%s+', '') == '' then
        lib.notify({
            title = 'Vehicle Status',
            description = 'Enter a plate or sit inside your vehicle and try again.',
            type = 'error'
        })
        return
    end

    TriggerServerEvent('qbx_vehicleinsurance:server:vehicleStatus', plate)
end, false)
