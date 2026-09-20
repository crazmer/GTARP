local logger = require '@qbx_core.modules.logger'

local activeGarageSpawns = {}

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@param player table
---@param depotPrice integer
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        return true
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        return true
    end
    return false
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    -- The client already prevents double-clicks, but this server-side lock is the
    -- authoritative protection against concurrent callbacks racing before the
    -- vehicle state is persisted as OUT.
    local lockKey = ('%s:%s'):format(tostring(source), tostring(vehicleId))
    if activeGarageSpawns and activeGarageSpawns[lockKey] then
        exports.qbx_core:Notify(source, locale('spawn_in_progress'), 'error')
        return
    end

    activeGarageSpawns = activeGarageSpawns or {}
    activeGarageSpawns[lockKey] = true

    local result
    local ok, err = xpcall(function()
        local garage = TryGetGarage(source, garageName)
        if not garage then return end
    
        local accessPoint = garage.accessPoints[accessPointIndex]
        if not accessPoint then
            logger.log({
                source = source,
                message = string.format(
                    'Attempted to spawn a vehicle from a non-existent access point index: %d for garage: %s',
                    accessPointIndex,
                    garageName
                ),
                webhook = Config.logging.webhook.error,
                event = 'error',
                color = 'red'
            })
    
            return
        end
    
        local distanceBetweenPlayerAndAccessPoint = #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz)
        if distanceBetweenPlayerAndAccessPoint > 3 then
            logger.log({
                source = source,
                message = string.format(
                    'Player attempted to spawn a vehicle but was too far from the access point. Distance: %.2f, Access Point Index: %d, Garage: %s',
                    distanceBetweenPlayerAndAccessPoint,
                    accessPointIndex,
                    garageName
                ),
                webhook = Config.logging.webhook.anticheat,
                event = 'suspicious',
                color = 'white'
            })
    
            return
        end
        local garageType = GetGarageType(garageName)
    
        local spawnCoords = accessPoint.spawn or accessPoint.coords
        if Config.distanceCheck then
            local nearbyVehicle = lib.getClosestVehicle(spawnCoords.xyz, Config.distanceCheck, false)
            if nearbyVehicle then
                exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
                return
            end
        end
    
        local filter = GetPlayerVehicleFilter(source, garageName)
        local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
        if not playerVehicle then
            exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
            return
        end

        -- Guard against a second request after the first vehicle has already
        -- been created but before its database state is saved as OUT.
        local vehicleAlreadySpawned = FindPlateOnServer(playerVehicle.props.plate)
        if vehicleAlreadySpawned then
            if garageType == GarageType.DEPOT then
                return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
            end

            exports.qbx_core:Notify(source, locale('spawn_in_progress'), 'error')
            return
        end
    
        if garageType == GarageType.DEPOT and playerVehicle.depotPrice then
            local player = exports.qbx_core:GetPlayer(source)
            OverrideFreeDepotPriceForOutVehicle(playerVehicle)
            local canPay = payDepotPrice(player, playerVehicle.depotPrice)
    
            if not canPay then
                exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
                return
            end
        end
    
        playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.
    
        local warpPed = Config.warpInVehicle and GetPlayerPed(source)
        local netId, veh = qbx.spawnVehicle({ spawnSource = spawnCoords, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})
    
        if Config.doorsLocked then
            if GetResourceState('qbx_vehiclekeys') == 'started' then
                TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
            else
                SetVehicleDoorsLocked(veh, 2)
            end
        end
    
        -- Garage vehicles are spawned server-side. Grant their keys through the
        -- trusted qbx_vehiclekeys server export instead of the legacy client bridge.
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            exports.qbx_vehiclekeys:GiveKeys(source, veh, true)
        else
            TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)
        end
    
        Entity(veh).state:set('vehicleid', vehicleId, false)
        setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
        TriggerEvent('qbx_garages:server:vehicleSpawned', veh)
        result = netId
    end, debug.traceback)

    activeGarageSpawns[lockKey] = nil

    if not ok then
        logger.log({
            source = source,
            message = ('Garage vehicle spawn failed: %s'):format(err),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })
        return
    end

    return result
end)


function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end
