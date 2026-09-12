BotRPPlayerState = BotRPPlayerState or {}

BotRPPlayerState.Config = {
    version = '0.1.0',
    events = {
        ready = 'botrp:playerstate:server:ready',
        updated = 'botrp:playerstate:server:updated',
        left = 'botrp:playerstate:server:left',
        clientReady = 'botrp:playerstate:client:ready',
        clientUpdated = 'botrp:playerstate:client:updated',
    },
}
