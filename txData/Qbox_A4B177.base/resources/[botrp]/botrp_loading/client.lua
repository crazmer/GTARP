local RESOURCE = GetCurrentResourceName()

local function setLoading(state, title, subtitle)
    SendNUIMessage({
        action = state and 'show' or 'hide',
        title = title or 'Welcome to BotRP',
        subtitle = subtitle or 'Preparing your character...',
    })
end

RegisterNetEvent('botrp_loading:client:show', function(title, subtitle)
    setLoading(true, title, subtitle)
end)

RegisterNetEvent('botrp_loading:client:hide', function()
    setLoading(false)
end)

-- Development trigger. This avoids chat/ACE command permissions entirely.
RegisterNetEvent('botrp_loading:client:toggleTest', function()
    SendNUIMessage({ action = 'toggle' })
end)

-- Qbox/QBCore compatibility: hide after the character has loaded.
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setLoading(false)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setLoading(false)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    setLoading(false)
end)

-- The loading UI is shown automatically while this resource initializes.
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= RESOURCE then return end
    CreateThread(function()
        Wait(500)
        setLoading(true, 'Welcome to BotRP', 'Preparing your character...')
    end)
end)

CreateThread(function()
    while GetResourceState('qbx_core') ~= 'started' do
        Wait(500)
    end
    print('[BotRP] loading v0.2.0 started')
end)
