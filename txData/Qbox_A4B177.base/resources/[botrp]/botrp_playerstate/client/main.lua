local state = nil

RegisterNetEvent(BotRPPlayerState.Config.events.clientReady, function(data)
    state = data
end)

RegisterNetEvent(BotRPPlayerState.Config.events.clientUpdated, function(data)
    state = data
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    state = nil
end)

CreateThread(function()
    Wait(1500)
    state = lib.callback.await('botrp:playerstate:get', false)
end)

exports('GetState', function()
    return state
end)

exports('IsReady', function()
    return state ~= nil
end)
