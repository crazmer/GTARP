# botrp_core

BotRP Core v0.1.0.

## Purpose

The first BotRP foundation resource. It provides a clean API boundary around
Qbox without modifying qbx_core or NPWD.

## Responsibilities

- Qbox player lifecycle detection
- Normalized player context
- BotRP lifecycle events
- Basic reusable exports
- Future foundation for identity, logging, economy, and gameplay resources

## Server exports

- `GetPlayerContext(source)`
- `IsPlayerReady(source)`
- `GetReadyPlayers()`
- `GetVersion()`

## Client exports

- `GetPlayerContext()`
- `IsPlayerReady()`
- `GetVersion()`

## Events

Server:
- `botrp:server:playerReady`
- `botrp:server:playerLeft`

Client:
- `botrp:client:playerReady`

## Installation

Place this resource at:

    resources/[botrp]/botrp_core

Then add, after the Qbox dependencies are started:

    ensure botrp_core

NPWD and the hosting/network configuration are intentionally untouched.
