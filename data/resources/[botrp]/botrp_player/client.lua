local currentState = nil

RegisterNetEvent('botrp:player:stateChanged', function(state)
    currentState = state
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('botrp:player:requestState')
end)

exports('GetState', function()
    return currentState
end)

exports('GetCharacterId', function()
    return currentState and currentState.characterId or nil
end)

exports('GetMoney', function(moneyType)
    if not currentState or not currentState.money then return 0 end
    return currentState.money[moneyType] or 0
end)

exports('GetMetadata', function(key)
    if not currentState or not currentState.metadata then return nil end
    return currentState.metadata[key]
end)
