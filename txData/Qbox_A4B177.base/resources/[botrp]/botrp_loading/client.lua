local RESOURCE = GetCurrentResourceName()
local visible = false

local function setLoading(state, title, subtitle)
    visible = state
    SendNUIMessage({
        action = state and 'show' or 'hide',
        title = title or 'Welcome to BotRP',
        subtitle = subtitle or 'Preparing your character...',
    })
    SetNuiFocus(false, false)
end

RegisterNetEvent('botrp_loading:client:show', function(title, subtitle)
    setLoading(true, title, subtitle)
end)

RegisterNetEvent('botrp_loading:client:hide', function()
    setLoading(false)
end)

RegisterCommand('+botrp_loading_test', function()
    if visible then
        setLoading(false)
    else
        setLoading(true, 'Welcome to BotRP', 'Loading your character...')
    end
end, false)

RegisterCommand('-botrp_loading_test', function() end, false)
RegisterKeyMapping('+botrp_loading_test', 'Toggle BotRP loading screen test', 'keyboard', 'F10')

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setLoading(true, 'Welcome to BotRP', 'Loading your character...')
    Wait(2500)
    setLoading(false)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    setLoading(false)
end)

CreateThread(function()
    Wait(1500)
    if GetResourceState('qbx_core') ~= 'started' then
        print(('[%s] qbx_core is not started.'):format(RESOURCE))
        return
    end
end)
