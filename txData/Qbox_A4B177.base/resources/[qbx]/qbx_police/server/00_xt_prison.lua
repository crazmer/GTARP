-- This server uses xt-prison as its authoritative prison system.
-- qbx_police/server/commands.lua loads before server/main.lua, so the
-- integration flag must exist before the command registrations run.
IsUsingXTPrison = true
