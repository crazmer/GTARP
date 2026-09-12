RegisterCommand('botrp_loading', function(source)
    if source == 0 then return end
    TriggerClientEvent('botrp_loading:client:show', source, 'Welcome to BotRP', 'Loading your character...')
end, false)
