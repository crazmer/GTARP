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

local function notify(message, notifyType)
    if framework == 'qbox' then
        local ok = pcall(function()
            exports.qbx_core:Notify(message, notifyType or 'inform')
        end)
        if ok then return true end
    elseif framework == 'qbcore' and QBCore then
        TriggerEvent('QBCore:Notify', message, notifyType or 'primary')
        return true
    end

    TriggerEvent('chat:addMessage', {
        color = { 120, 190, 255 },
        multiline = true,
        args = { 'BotRP', message }
    })

    return true
end

exports('GetFramework', function()\n    detectFramework()\n    return framework\nend)\n\nexports('HasResource', function(resourceName)\n    return resourceName and GetResourceState(resourceName) == 'started'\nend)
exports('Notify', notify)

AddEventHandler('onClientResourceStart', function(resourceName)\n    if resourceName == 'qbx_core' or resourceName == 'qb-core' then\n        detectFramework()\n    end\nend)\n\nRegisterNetEvent('botrp:bridge:notify', function(message, notifyType)
    notify(message, notifyType)
end)

CreateThread(function()
    detectFramework()
    print(('[BotRP] Client compatibility bridge: %s'):format(framework))
end)
