# BotRP Main Security Remediation Status

Updated: 2026-09-14

## Current main status

The active `txData/Qbox_A4B177.base/server.cfg` now loads credentials from the untracked `secrets.cfg` file instead of storing the FiveM license key or database password in the tracked startup configuration. `.gitignore` excludes `secrets.cfg`, and the old tracked `server.cfg.bkp` containing credentials has been removed from the current tree.

The invalid `sv_enforceGameBuild 3258` setting is no longer present in the active startup configuration. The old `sessionmanager`, `hardcap`, and `[assets]` ensures identified in the historical 2026-09-12 startup configuration are also no longer present in the active configuration.

Renewed-Banking contains server-side authorization for player-initiated organization/shared-account operations.

## Character-system hardening completed

- BotRP character deletion now uses the authenticated `qbx_core:server:deleteCharacter` callback rather than the legacy client-triggerable event.
- The legacy `qbx_core:server:deleteCharacter` event was removed from the character callback resource.
- BotRP NUI character actions are serialized so rapid selection, deletion, creation, or play clicks cannot race the preview state.
- Character preview data is restricted server-side to characters owned by the requesting account.
- Character creation now validates gender and the configured `YYYY-MM-DD` birth-date format server-side.
- Character slot/cid assignment remains server-authoritative.

## Operator actions still required

1. Rotate the previously exposed FiveM license key and database password. Removing them from the current tree does not erase values from Git history.
2. Keep `secrets.cfg` deployment-local and untracked.
3. Use a least-privilege database account for production.
4. Perform a clean Enhanced boot and verify database, Qbox/OX, NPWD, voice, banking authorization, appearance persistence, vehicle persistence/keys, and weather/time synchronization.
5. Test character create, switch, delete, repeated delete clicks, and reconnect/logout flows in-game after restarting the affected resources.

## Verification note

GitHub source inspection confirms the code/config changes above. A live FiveM client/server runtime test is still required to prove there are no artifact-specific streaming, resource-start, or gameplay regressions.