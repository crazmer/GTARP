local RESOURCE = GetCurrentResourceName()
local playerContext = nil

RegisterNetEvent(BotRP.Config.events.playerReadyClient, function(context)
    playerContext = context

    if BotRP.Config.debug then
        print(('[%s] character ready: %s (%s)'):format(
            RESOURCE,
            context.name or 'Unknown',
            context.citizenid or 'unknown'
        ))
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    playerContext = nil
end)

exports('GetPlayerContext', function()
    return playerContext
end)

exports('IsPlayerReady', function()
    return playerContext ~= nil
end)

exports('GetVersion', function()
    return BotRP.Config.resourceVersion
end)

CreateThread(function()
    Wait(1000)

    if GetResourceState('qbx_core') ~= 'started' then
        print(('[%s] qbx_core is not started; BotRP core is waiting.'):format(RESOURCE))
        return
    end

    playerContext = lib.callback.await('botrp:server:getPlayerContext', false)
end)
