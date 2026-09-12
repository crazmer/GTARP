BotRPIdentity = BotRPIdentity or {}

BotRPIdentity.Config = {
    version = '0.2.1',
    events = {
        ready = 'botrp:identity:server:ready',
        updated = 'botrp:identity:client:updated',
    },
    coreEvents = {
        -- botrp_core emits these exact server-side event names.
        playerReady = 'botrp:server:playerReady',
        playerLeft = 'botrp:server:playerLeft',
    },
}
