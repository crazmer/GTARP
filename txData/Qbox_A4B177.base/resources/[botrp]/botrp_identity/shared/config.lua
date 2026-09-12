BotRPIdentity = BotRPIdentity or {}

BotRPIdentity.Config = {
    version = '0.4.0',
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
        grades = {},
        maxDistance = 4.0,
    },
    licenses = {
        driving = { label = 'Driving License' },
        motorcycle = { label = 'Motorcycle License' },
        weapon = { label = 'Weapon License' },
    },
}
