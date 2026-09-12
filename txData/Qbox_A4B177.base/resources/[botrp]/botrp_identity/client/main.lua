local identity = nil

RegisterNetEvent(BotRPIdentity.Config.events.updated, function(data)
    identity = data
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    identity = nil
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    identity = lib.callback.await('botrp:identity:get', false)
end)

exports('GetIdentity', function()
    return identity
end)

exports('IsLoaded', function()
    return identity ~= nil
end)

exports('GetVersion', function()
    return BotRPIdentity.Config.version
end)

CreateThread(function()
    Wait(1500)

    if GetResourceState('qbx_core') ~= 'started' then return end
    identity = lib.callback.await('botrp:identity:get', false)
end)
