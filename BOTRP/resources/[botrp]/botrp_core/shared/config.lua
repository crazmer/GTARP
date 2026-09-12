BotRP = BotRP or {}

BotRP.Config = {
    debug = false,
    resourceVersion = '0.1.0',

    events = {
        playerReady = 'botrp:server:playerReady',
        playerReadyClient = 'botrp:client:playerReady',
        playerLeft = 'botrp:server:playerLeft',
    }
}
