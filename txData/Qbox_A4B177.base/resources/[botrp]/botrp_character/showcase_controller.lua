local config = require 'config'

local active = false

local function stopShowcase()
    active = false
    if NewLoadSceneStop then NewLoadSceneStop() end
    ClearFocus()
end

RegisterNUICallback('showcaseState', function(data, cb)
    active = data and data.active == true
    if not active then
        stopShowcase()
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if active then
            local location = config.locations and config.locations[1]
            local ped = location and location.pedCoords
            local cam = location and location.camCoords

            if ped and cam then
                local focusX = (ped.x + cam.x) * 0.5
                local focusY = (ped.y + cam.y) * 0.5
                local focusZ = (ped.z + cam.z) * 0.5

                -- Keep the remote GTA showcase area streamed for the whole lobby.
                -- Do not restart NewLoadScene every frame: that can cause visible
                -- world handoff flashes and make the scene appear to reload.
                SetFocusPosAndVel(focusX, focusY, focusZ, 0.0, 0.0, 0.0)
                RequestCollisionAtCoord(ped.x, ped.y, ped.z)
                RequestCollisionAtCoord(cam.x, cam.y, cam.z)
                RequestAdditionalCollisionAtCoord(ped.x, ped.y, ped.z)
                RequestAdditionalCollisionAtCoord(cam.x, cam.y, cam.z)
            end

            Wait(0)
        else
            Wait(250)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        stopShowcase()
    end
end)
