BotRPIdentity = BotRPIdentity or {}

BotRPIdentity.Config = {
    version = '0.1.0',
    events = {
        ready = 'botrp:identity:server:ready',
        updated = 'botrp:identity:client:updated',
    },
}
