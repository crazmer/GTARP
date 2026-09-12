# botrp_playerstate

BotRP centralized player state service for Qbox.

Provides a normalized server-side state cache and client-side state export so future BotRP resources can consume player data through one stable interface.

## Exports

Server:
- `GetState(source)`
- `IsReady(source)`
- `GetAll()`
- `Refresh(source, reason)`

Client:
- `GetState()`
- `IsReady()`

## Design

The resource reads Qbox PlayerData at the boundary and keeps downstream BotRP resources independent from direct Qbox reads where practical.
