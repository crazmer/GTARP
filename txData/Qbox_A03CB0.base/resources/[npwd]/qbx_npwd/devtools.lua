local devMode = GetConvarInt('qbx_npwd:devMode', 0) == 1

if not devMode then return end

local function notify(message)
    lib.notify({
        title = 'NPWD Developer Tools',
        description = message,
        type = 'inform'
    })
end

RegisterCommand('phone_test', function()
    if GetResourceState('npwd') ~= 'started' then
        notify('NPWD is not started.')
        return
    end

    exports.npwd:setPhoneVisible(true)
    notify('Phone opened. Developer mode is enabled.')
end, false)

RegisterCommand('phone_test_close', function()
    if GetResourceState('npwd') ~= 'started' then return end
    exports.npwd:setPhoneVisible(false)
    notify('Phone closed.')
end, false)

RegisterCommand('phone_test_status', function()
    local hasPhone = exports.qbx_npwd:HasPhone()
    notify(('Phone item detected: %s'):format(hasPhone and 'YES' or 'NO'))
end, false)

RegisterKeyMapping('phone_test', 'Open phone (developer test mode)', 'keyboard', 'F10')
