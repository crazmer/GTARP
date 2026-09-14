local config = require 'config'
local showcaseActive = false
local sceneStarted = false

local function stopShowcaseStreaming()
    showcaseActive = false
    sceneStarted = false
    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()
end

RegisterNUICallback('showcaseState', function(data, cb)
    showcaseActive = data and data.active == true
    if not showcaseActive then
        stopShowcaseStreaming()
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if showcaseActive then
            local location = config.locations and config.locations[1]
            local pedCoords = location and location.pedCoords
            local camCoords = location and location.camCoords
            if pedCoords and camCoords then
                local focusX = (pedCoords.x + camCoords.x) * 0.5
                local focusY = (pedCoords.y + camCoords.y) * 0.5
                local focusZ = (pedCoords.z + camCoords.z) * 0.5

                SetFocusPosAndVel(focusX, focusY, focusZ, 0.0, 0.0, 0.0)
                RequestCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                RequestCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)
                RequestAdditionalCollisionAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
                RequestAdditionalCollisionAtCoord(camCoords.x, camCoords.y, camCoords.z)

                if not sceneStarted and NewLoadSceneStartSphere then
                    sceneStarted = NewLoadSceneStartSphere(focusX, focusY, focusZ, 220.0, 0)
                end

                if sceneStarted and IsNewLoadSceneLoaded() then
                    -- Keep streaming focus alive for the entire character-lobby session.
                    -- The main preview script can create/destroy its camera independently.
                end
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        stopShowcaseStreaming()
    end
end)
