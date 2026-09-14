-- Prevent the brief post-loading gameplay view while the remote character
-- showcase is still streaming. client.lua owns the actual lobby handoff.
CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(0)
    end

    DoScreenFadeOut(0)
    Wait(250)
    TriggerEvent('botrp_character:client:open')
end)
