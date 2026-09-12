BotRPIdentity = BotRPIdentity or {}

BotRPIdentity.Config = {
    version = '0.1.1',
    events = {
        ready = 'botrp:identity:server:ready',
        updated = 'botrp:identity:client:updated',
    },
    coreEvents = {
        playerReady = 'botrp:core:server:playerReady',
        playerLeft = 'botrp:core:server:playerLeft',
    },
}
