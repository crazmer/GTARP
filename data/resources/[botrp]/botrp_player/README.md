# BotRP Player

Framework-independent player state service.

## Responsibilities

This resource owns transient player state such as:
- identifier
- active character id
- cash and bank balances
- metadata
- permission group

It intentionally does NOT own:
- character creation
- appearance
- inventory
- jobs
- vehicles
- database persistence
- QBCore/Qbox internals

## Server exports

GetState(source)
GetCharacterId(source)
SetCharacterId(source, characterId)
GetMoney(source, moneyType)
AddMoney(source, moneyType, amount)
RemoveMoney(source, moneyType, amount)
GetMetadata(source, key)
SetMetadata(source, key, value)
GetPermissionGroup(source)

## Client exports

GetState()
GetCharacterId()
GetMoney(moneyType)
GetMetadata(key)

Persistence should be added through a separate storage resource/adapter so this resource remains portable.
