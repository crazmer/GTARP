BotRPIdentity = BotRPIdentity or {}

BotRPIdentity.Config = {
    version = '0.3.0',
    events = {
        ready = 'botrp:identity:server:ready',
        updated = 'botrp:identity:client:updated',
        verification = 'botrp:identity:client:verification',
    },
    coreEvents = {
        playerReady = 'botrp:server:playerReady',
        playerLeft = 'botrp:server:playerLeft',
    },
    police = {
        jobs = {
            police = true,
            sheriff = true,
            statepolice = true,
        },
        grades = {}, -- Optional: set job grade numbers to restrict verification further.
        maxDistance = 4.0,
    },
}
