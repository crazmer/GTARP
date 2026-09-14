local RESOURCE = GetCurrentResourceName()
local nativeClosed = false

local function closeNativeLoadscreen()
    if nativeClosed then return end
    nativeClosed = true
    ShutdownLoadingScreenNui()
end

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
    closeNativeLoadscreen()
end)

RegisterNetEvent('botrp_loading:client:toggleTest', function()
    SendNUIMessage({ action = 'toggle' })
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setLoading(false)
    closeNativeLoadscreen()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setLoading(false)
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    setLoading(false)
end)

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
