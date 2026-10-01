# BotRP Compatibility Bridge

The bridge provides one stable API for BotRP resources.

Supported modes:
- standalone
- QBCore
- Qbox

Framework detection is automatic by default and no framework is a hard dependency.

Server exports:
- GetFramework()
- GetPlayer(source)
- GetPlayerData(source)
- GetIdentifier(source)
- Notify(source, message, type)
- SetJob(source, job, grade)
- AddMoney(source, type, amount, reason)
- RemoveMoney(source, type, amount, reason)

Client exports:
- GetFramework()
- Notify(message, type)

BotRP resources should use the bridge instead of directly importing a framework.

Do not read another resource's database tables or assume a particular inventory, target, voice, or phone resource.

Optional ecosystem integrations can be added behind adapters:
- ox_lib
- oxmysql
- ox_target
- ox_inventory
- other compatible resources
