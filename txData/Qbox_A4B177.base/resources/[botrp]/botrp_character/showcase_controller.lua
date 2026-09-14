local config = require 'config'

local active = false
local sceneStarted = false

local function stopShowcase()
    active = false
    sceneStarted = false
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

                -- Keep the remote GTA area streamed for the whole lobby session.
                SetFocusPosAndVel(focusX, focusY, focusZ, 0.0, 0.0, 0.0)
                RequestCollisionAtCoord(ped.x, ped.y, ped.z)
                RequestCollisionAtCoord(cam.x, cam.y, cam.z)
                RequestAdditionalCollisionAtCoord(ped.x, ped.y, ped.z)
                RequestAdditionalCollisionAtCoord(cam.x, cam.y, cam.z)

                -- Re-start a load scene if the preview script has stopped it after
                -- creating the camera. Focus remains active between frames.
                if NewLoadSceneStartSphere and (not sceneStarted or not IsNewLoadSceneLoaded()) then
                    sceneStarted = NewLoadSceneStartSphere(focusX, focusY, focusZ, 260.0, 0)
                end

                -- The existing preview script used a very tight 27 FOV, which made
                -- the ped dominate the screen and made the world feel missing.
                -- Widen it to a cinematic character-showcase framing.
                local renderingCam = GetRenderingCam()
                if renderingCam and renderingCam ~= 0 and DoesCamExist(renderingCam) then
                    SetCamFov(renderingCam, 38.0)
                    SetCamNearDof(renderingCam, 1.2)
                    SetCamFarDof(renderingCam, 18.0)
                    SetCamDofStrength(renderingCam, 0.18)
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
        stopShowcase()
    end
end)
