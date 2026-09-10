local devMode = GetConvarInt('qbx_npwd:devMode', 0) == 1

if not devMode then return end

local function notify(message, kind)
    if lib and lib.notify then
        lib.notify({
            title = 'NPWD Developer Tools',
            description = message,
            type = kind or 'inform'
        })
    end
    print(('[qbx_npwd] %s'):format(message))
end

local function isNpwdStarted()
    return GetResourceState('npwd') == 'started'
end

RegisterCommand('phone_test', function()
    if not isNpwdStarted() then
        notify('NPWD is not started.', 'error')
        return
    end

    local ok, result = pcall(function()
        return exports.npwd:setPhoneVisible(true)
    end)

    if ok then
        notify(('Phone open request sent%s.'):format(result ~= nil and (' (result: ' .. tostring(result) .. ')') or ''))
    else
        notify(('Failed to open NPWD: %s'):format(tostring(result)), 'error')
    end
end, false)

RegisterCommand('phone_test_close', function()
    if not isNpwdStarted() then
        notify('NPWD is not started.', 'error')
        return
    end

    local ok, result = pcall(function()
        return exports.npwd:setPhoneVisible(false)
    end)

    if ok then
        notify(('Phone close request sent%s.'):format(result ~= nil and (' (result: ' .. tostring(result) .. ')') or ''))
    else
        notify(('Failed to close NPWD: %s'):format(tostring(result)), 'error')
    end
end, false)

RegisterCommand('phone_test_status', function()
    local npwdState = GetResourceState('npwd')
    local bridgeState = GetResourceState('qbx_npwd')
    local hasPhone = false

    if bridgeState == 'started' then
        local ok, result = pcall(function()
            return exports.qbx_npwd:HasPhone()
        end)
        hasPhone = ok and result == true
    end

    notify(('NPWD: %s | Qbox bridge: %s | Phone item: %s'):format(
        npwdState,
        bridgeState,
        hasPhone and 'YES' or 'NO'
    ))
end, false)

RegisterKeyMapping('phone_test', 'Open phone (developer test mode)', 'keyboard', 'F10')

print('[qbx_npwd] Developer tools enabled: /phone_test, /phone_test_close, /phone_test_status, F10')
