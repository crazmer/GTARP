local framework = 'standalone'
local QBCore = nil

local function resourceStarted(name)
    return GetResourceState(name) == 'started'
end

local function detectFramework()
    local requested = BotRPBridgeConfig.framework

    if requested == 'qbox' or (requested == 'auto' and resourceStarted('qbx_core')) then
        framework = 'qbox'
        return
    end

    if requested == 'qbcore' or (requested == 'auto' and resourceStarted('qb-core')) then
        framework = 'qbcore'
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok then QBCore = core end
        return
    end

    framework = 'standalone'
end

local function getPlayer(source)
    if framework == 'qbox' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(source)
        end)
        return ok and player or nil
    end

    if framework == 'qbcore' and QBCore then
        return QBCore.Functions.GetPlayer(source)
    end

    return nil
end

local function getPlayerData(source)
    local player = getPlayer(source)
    return player and player.PlayerData or nil
end

local function getIdentifier(source)
    local data = getPlayerData(source)
    if data then
        return data.citizenid or data.license
    end

    return GetPlayerIdentifierByType(source, 'license') or ('source:%s'):format(source)
end

local function notify(source, message, notifyType)
    if framework == 'qbox' then
        local ok = pcall(function()
            exports.qbx_core:Notify(source, message, notifyType or 'inform')
        end)
        if ok then return true end
    elseif framework == 'qbcore' and QBCore then
        TriggerClientEvent('QBCore:Notify', source, message, notifyType or 'primary')
        return true
    end

    TriggerClientEvent('botrp:bridge:notify', source, message, notifyType or 'inform')
    return true
end

local function setJob(source, jobName, grade)
    if framework == 'qbox' then
        local ok, result = pcall(function()
            return exports.qbx_core:SetJob(source, jobName, grade or 0)
        end)
        return ok and result or false
    end

    if framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.Functions.SetJob(jobName, grade or 0) or false
    end

    return false
end

local function addMoney(source, moneyType, amount, reason)
    if framework == 'qbox' then
        local ok, result = pcall(function()
            return exports.qbx_core:AddMoney(source, moneyType, amount, reason)
        end)
        return ok and result or false
    end

    if framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.Functions.AddMoney(moneyType, amount, reason) or false
    end

    return false
end

local function removeMoney(source, moneyType, amount, reason)
    if framework == 'qbox' then
        local ok, result = pcall(function()
            return exports.qbx_core:RemoveMoney(source, moneyType, amount, reason)
        end)
        return ok and result or false
    end

    if framework == 'qbcore' and QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        return player and player.Functions.RemoveMoney(moneyType, amount, reason) or false
    end

    return false
end

exports('GetFramework', function()\n    detectFramework()\n    return framework\nend)\n\nexports('HasResource', function(resourceName)\n    return resourceName and GetResourceState(resourceName) == 'started'\nend)
exports('GetPlayer', getPlayer)
exports('GetPlayerData', getPlayerData)
exports('GetIdentifier', getIdentifier)
exports('Notify', notify)
exports('SetJob', setJob)
exports('AddMoney', addMoney)
exports('RemoveMoney', removeMoney)

CreateThread(function()
    detectFramework()
    print('========================================')
    print('       BotRP Compatibility Bridge')
    print('========================================')
    print(('[BotRP] API version: %s'):format(BotRPBridgeConfig.apiVersion))
    print(('[BotRP] Framework mode: %s'):format(framework))
    print(('[BotRP] ox_lib optional: %s'):format(tostring(BotRPBridgeConfig.useOxLib)))
    print(('[BotRP] oxmysql optional: %s'):format(tostring(BotRPBridgeConfig.useOxMySQL)))
    print('[BotRP] Bridge initialized.')
    print('========================================')
end)
