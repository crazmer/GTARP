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

-- Development test controls. These are local client commands and do not
-- require ACE permissions. The commands intentionally use unique names so
-- they do not conflict with server/admin command permissions.
RegisterCommand('botrp_toggle_loading', function()
    setLoading(not visible, 'Welcome to BotRP', 'Loading your character...')
end, false)

RegisterCommand('botrp_toggle_loading_f9', function()
    setLoading(not visible, 'Welcome to BotRP', 'Loading your character...')
end, false)

RegisterKeyMapping('botrp_toggle_loading', 'BotRP loading screen test', 'keyboard', 'F10')
RegisterKeyMapping('botrp_toggle_loading_f9', 'BotRP loading screen fallback test', 'keyboard', 'F9')

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setLoading(true, 'Welcome to BotRP', 'Loading your character...')
    Wait(2500)
    setLoading(false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setLoading(false)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    setLoading(false)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then return end
    Wait(1000)
    setLoading(true, 'Welcome to BotRP', 'Preparing your character...')
    Wait(3000)
    setLoading(false)
end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do
        Wait(500)
    end
    print('[BotRP] loading v0.1.3 started - F10/F9 test bindings registered')
end)
