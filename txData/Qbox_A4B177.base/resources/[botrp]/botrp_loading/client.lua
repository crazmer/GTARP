-- botrp_loading is a native FiveM loadscreen.
-- The loadscreen page receives FiveM's loadProgress messages directly and
-- is closed by FiveM when the native loading phase completes.
-- Keeping this resource free of manual shutdown logic prevents a stuck
-- loading screen from blocking the player from reaching the character flow.

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do
        Wait(500)
    end
    print('[BotRP] loading v0.2.1 started')
end)
