# botrp_identity

BotRP Identity v0.1.0.

A standalone identity service built on top of `botrp_core` and Qbox. It keeps BotRP gameplay resources from reaching directly into Qbox character data for common identity reads.

## Responsibilities

- Normalize the active character's identity.
- Provide server and client exports.
- Refresh identity when BotRP core marks a character ready.
- Clear identity when the character logs out or the player leaves.
- Provide a small `/botrp_identity` diagnostic command.

## Server exports

- `GetIdentity(source)`
- `GetIdentities()`
- `IsLoaded(source)`
- `GetVersion()`

## Client exports

- `GetIdentity()`
- `IsLoaded()`
- `GetVersion()`

## Identity fields

- source
- citizenid
- license
- name
- firstname
- lastname
- birthdate
- gender
- nationality
- phone
- cid

## Installation

The resource is installed at:

    resources/[botrp]/botrp_identity

`server.cfg` starts it after `botrp_core` and before the NPWD resources.

This resource does not change NPWD, Qbox core files, or hosting/network configuration.
