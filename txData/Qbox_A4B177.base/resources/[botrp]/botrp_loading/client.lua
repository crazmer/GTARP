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

-- Manual test command. This is intentionally a local client command and
-- does not require ACE permissions.
RegisterCommand('botrp_loading', function()
    setLoading(not visible, 'Welcome to BotRP', 'Loading your character...')
end, false)

RegisterKeyMapping('botrp_loading', 'Toggle BotRP loading screen', 'keyboard', 'F10')

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
    print('[BotRP] loading v0.1.4 started - /botrp_loading available')
end)
