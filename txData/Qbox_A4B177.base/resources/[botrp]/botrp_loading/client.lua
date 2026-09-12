local RESOURCE = GetCurrentResourceName()
local visible = false
local testCommand = ('+%s'):format(RESOURCE)
local releaseCommand = ('-%s'):format(RESOURCE)

local function setLoading(state, title, subtitle)
    visible = state
    SendNUIMessage({
        action = state and 'show' or 'hide',
        title = title or 'Welcome to BotRP',
        subtitle = subtitle or 'Preparing your character...',
    })
    if state then
        SetNuiFocus(false, false)
    end
end

RegisterNetEvent('botrp_loading:client:show', function(title, subtitle)
    setLoading(true, title, subtitle)
end)

RegisterNetEvent('botrp_loading:client:hide', function()
    setLoading(false)
end)

RegisterCommand(testCommand, function()
    setLoading(not visible, 'Welcome to BotRP', 'Loading your character...')
end, false)
RegisterCommand(releaseCommand, function() end, false)
RegisterKeyMapping(testCommand, 'Toggle BotRP loading screen test', 'keyboard', 'F10')

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
    print('[BotRP] loading v0.1.1 started')
end)
