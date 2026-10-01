RegisterNetEvent('botrp:core:sessionReady', function(data)
    print('[BotRP Core] Client session ready.')
    print(('[BotRP Core] Identifier: %s'):format(data.identifier or 'unknown'))
end)

CreateThread(function()
    print('[BotRP Core] Client initialized.')

    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    print('[BotRP Core] Network session started.')
end)
