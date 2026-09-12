local cachedAccounts = {}
local cachedPlayers = {}

CreateThread(function()
    Wait(500)
    if not LoadResourceFile("Renewed-Banking", 'web/public/build/bundle.js') or GetCurrentResourceName() ~= "Renewed-Banking" then
        error(locale("ui_not_built"))
        return StopResource("Renewed-Banking")
    end
    local accounts = MySQL.query.await('SELECT * FROM bank_accounts_new', {})
    if accounts then
        for _,v in pairs (accounts) do
            local job = v.id
            v.auth = json.decode(v.auth)
            cachedAccounts[job] = {
                id = job,
                type = locale("org"),
                name = GetSocietyLabel(job),
                frozen = v.isFrozen == 1,
                amount = v.amount,
                transactions = json.decode(v.transactions),
                auth = {},
                creator = v.creator
            }
            if #v.auth >= 1 then
                for k=1, #v.auth do
                    cachedAccounts[job].auth[v.auth[k]] = true
                end
            end
        end
    end
    local jobs, gangs = GetFrameworkGroups()
    local query = {}
    local function addCachedAccount(group)
        cachedAccounts[group] = {
            id = group,
            type = locale('org'),
            name = GetSocietyLabel(group),
            frozen = 0,
            amount = 0,
            transactions = {},
            auth = {},
            creator = nil
        }
        query[#query + 1] = {"INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator) VALUES (?, ?, ?, ?, ?, NULL) ",
        { group, cachedAccounts[group].amount, json.encode(cachedAccounts[group].transactions), json.encode({}), cachedAccounts[group].frozen }}
    end
    for job in pairs(jobs) do
        if not cachedAccounts[job] then addCachedAccount(job) end
    end
    for gang in pairs(gangs) do
        if not cachedAccounts[gang] then addCachedAccount(gang) end
    end
    if #query >= 1 then MySQL.transaction.await(query) end
end)

function UpdatePlayerAccount(cid)
    local p = promise.new()
    MySQL.query('SELECT * FROM player_transactions WHERE id = ?', {cid}, function(account)
        local query = '%' .. cid .. '%'
        MySQL.query("SELECT * FROM bank_accounts_new WHERE auth LIKE ? ", {query}, function(shared)
            cachedPlayers[cid] = {
                isFrozen = 0,
                transactions = #account > 0 and json.decode(account[1].transactions) or {},
                accounts = {}
            }
            if #shared >= 1 then
                for k=1, #shared do cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = shared[k].id end
            end
            p:resolve(true)
        end)
    end)
    return Citizen.Await(p)
end

local function getBankData(source)
    local Player = GetPlayerObject(source)
    local bankData = {}
    local cid = GetIdentifier(Player)
    if not cachedPlayers[cid] then UpdatePlayerAccount(cid) end
    local funds = GetFunds(Player)
    bankData[#bankData+1] = {
        id = cid, type = locale("personal"), name = GetCharacterName(Player),
        frozen = cachedPlayers[cid].isFrozen, amount = funds.bank, cash = funds.cash,
        transactions = cachedPlayers[cid].transactions,
    }
    local jobs = GetJobs(Player)
    if #jobs > 0 then
        for k=1, #jobs do
            if cachedAccounts[jobs[k].name] and IsJobAuth(jobs[k].name, jobs[k].grade) then bankData[#bankData+1] = cachedAccounts[jobs[k].name] end
        end
    else
        local job = cachedAccounts[jobs.name]
        if job and IsJobAuth(jobs.name, jobs.grade) then bankData[#bankData+1] = job end
    end
    local gang = GetGang(Player)
    if gang and gang ~= 'none' then
        local gangData = cachedAccounts[gang]
        if gangData and IsGangAuth(Player, gang) then bankData[#bankData+1] = gangData end
    end
    local sharedAccounts = cachedPlayers[cid].accounts
    for k=1, #sharedAccounts do
        local sAccount = cachedAccounts[sharedAccounts[k]]
        if sAccount then bankData[#bankData+1] = sAccount end
    end
    return bankData
end

lib.callback.register('renewed-banking:server:initalizeBanking', function(source) return getBankData(source) end)

local function genTransactionID()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

local function sanitizeMessage(message)
    if type(message) ~= "string" then message = tostring(message) end
    return message:gsub("'", "''"):gsub("\\", "\\\\")
end

local Type = type
local function handleTransaction(account, title, amount, message, issuer, receiver, transType, transID)
    if not account or Type(account) ~= 'string' then return print(locale("err_trans_account", account)) end
    if not title or Type(title) ~= 'string' then return print(locale("err_trans_title", title)) end
    if not amount or Type(amount) ~= 'number' then return print(locale("err_trans_amount", amount)) end
    if not message or Type(message) ~= 'string' then return print(locale("err_trans_message", message)) end
    if not issuer or Type(issuer) ~= 'string' then return print(locale("err_trans_issuer", issuer)) end
    if not receiver or Type(receiver) ~= 'string' then return print(locale("err_trans_receiver", receiver)) end
    if not transType or Type(transType) ~= 'string' then return print(locale("err_trans_type", transType)) end
    if transID and Type(transID) ~= 'string' then return print(locale("err_trans_transID", transID)) end
    local transaction = {
        trans_id = transID or genTransactionID(), title = title, amount = amount, trans_type = transType,
        receiver = receiver, message = sanitizeMessage(message), issuer = issuer, time = os.time()
    }
    if cachedAccounts[account] then
        table.insert(cachedAccounts[account].transactions, 1, transaction)
        local transactions = json.encode(cachedAccounts[account].transactions)
        MySQL.prepare("INSERT INTO bank_accounts_new (id, transactions) VALUES (?, ?) ON DUPLICATE KEY UPDATE transactions = ?", {account, transactions, transactions})
    elseif cachedPlayers[account] then
        table.insert(cachedPlayers[account].transactions, 1, transaction)
        local transactions = json.encode(cachedPlayers[account].transactions)
        MySQL.prepare("INSERT INTO player_transactions (id, transactions) VALUES (?, ?) ON DUPLICATE KEY UPDATE transactions = ?", {account, transactions, transactions})
    else
        print(locale("invalid_account", account))
    end
    return transaction
end
exports("handleTransaction", handleTransaction)

function GetAccountMoney(account)
    if not cachedAccounts[account] then locale("invalid_account", account) return false end
    return cachedAccounts[account].amount
end
exports('getAccountMoney', GetAccountMoney)

local function updateBalance(account)
    MySQL.prepare("UPDATE bank_accounts_new SET amount = ? WHERE id = ?", {cachedAccounts[account].amount, account})
end

function AddAccountMoney(account, amount)
    if not cachedAccounts[account] then locale("invalid_account", account) return false end
    cachedAccounts[account].amount += amount
    updateBalance(account)
    return true
end
exports('addAccountMoney', AddAccountMoney)

local function getPlayerData(source, id)
    local Player = source and GetPlayerObject(source)
    if not Player then Player = GetPlayerObjectFromID(id) end
    if not Player then
        local msg = ("Cannot Find Account(%s)"):format(id)
        print(locale("invalid_account", id))
        if source then Notify(source, {title = locale("bank_name"), description = msg, type = "error"}) end
    end
    return Player
end

-- Server-side authorization for every player-initiated organization/shared account operation.
-- Personal accounts are identified by the player's own framework identifier.
local function canAccessAccount(source, account)
    if type(account) ~= "string" or account == "" then return false end
    local Player = GetPlayerObject(source)
    if not Player then return false end
    local cid = GetIdentifier(Player)
    if account == cid then return true end

    local cached = cachedAccounts[account]
    if not cached then return false end
    if cached.auth and cached.auth[cid] then return true end

    local jobs = GetJobs(Player)
    if jobs then
        if #jobs > 0 then
            for i = 1, #jobs do
                if jobs[i].name == account and IsJobAuth(jobs[i].name, jobs[i].grade) then return true end
            end
        elseif jobs.name == account and IsJobAuth(jobs.name, jobs.grade) then
            return true
        end
    end

    local gang = GetGang(Player)
    if gang == account and gang ~= 'none' and IsGangAuth(Player, gang) then return true end
    return false
end

local function rejectUnauthorized(source, account)
    print(("[Renewed-Banking] Unauthorized account access attempt by source %s for account %s"):format(source, tostring(account)))
    Notify(source, {title = locale("bank_name"), description = locale("illegal_action", GetPlayerName(source)), type = "error"})
    return false
end

lib.callback.register('Renewed-Banking:server:deposit', function(source, data)
    if type(data) ~= "table" then return false end
    local Player = GetPlayerObject(source)
    if not Player then return false end
    local amount = tonumber(data.amount)
    if not amount or amount < 1 then
        Notify(source, {title = locale("bank_name"), description = locale("invalid_amount", "deposit"), type = "error"})
        return false
    end
    if cachedAccounts[data.fromAccount] and not canAccessAccount(source, data.fromAccount) then return rejectUnauthorized(source, data.fromAccount) end
    local name = GetCharacterName(Player)
    if not data.comment or data.comment == "" then data.comment = locale("comp_transaction", name, "deposited", amount) else data.comment = sanitizeMessage(data.comment) end
    if RemoveMoney(Player, amount, 'cash', data.comment) then
        if cachedAccounts[data.fromAccount] then AddAccountMoney(data.fromAccount, amount) else AddMoney(Player, amount, 'bank', data.comment) end
        local Player2 = getPlayerData(source, data.fromAccount)
        Player2 = Player2 and GetCharacterName(Player2) or data.fromAccount
        handleTransaction(data.fromAccount, locale("personal_acc") .. data.fromAccount, amount, data.comment, name, Player2, "deposit")
        return getBankData(source)
    end
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money"))
    return false
end)

function RemoveAccountMoney(account, amount)
    if not cachedAccounts[account] then print(locale("invalid_account", account)) return false end
    if cachedAccounts[account].amount < amount then print(locale("broke_account", account, amount)) return false end
    cachedAccounts[account].amount -= amount
    updateBalance(account)
    return true
end
exports('removeAccountMoney', RemoveAccountMoney)

lib.callback.register('Renewed-Banking:server:withdraw', function(source, data)
    if type(data) ~= "table" then return false end
    local Player = GetPlayerObject(source)
    if not Player then return false end
    local amount = tonumber(data.amount)
    if not amount or amount < 1 then
        Notify(source, {title = locale("bank_name"), description = locale("invalid_amount", "withdraw"), type = "error"})
        return false
    end
    if cachedAccounts[data.fromAccount] and not canAccessAccount(source, data.fromAccount) then return rejectUnauthorized(source, data.fromAccount) end
    local name = GetCharacterName(Player)
    local funds = GetFunds(Player)
    if not data.comment or data.comment == "" then data.comment = locale("comp_transaction", name, "withdrawed", amount) else data.comment = sanitizeMessage(data.comment) end
    local canWithdraw
    if cachedAccounts[data.fromAccount] then canWithdraw = RemoveAccountMoney(data.fromAccount, amount)
    else canWithdraw = funds.bank >= amount and RemoveMoney(Player, amount, 'bank', data.comment) or false end
    if canWithdraw then
        local Player2 = getPlayerData(source, data.fromAccount)
        Player2 = Player2 and GetCharacterName(Player2) or data.fromAccount
        AddMoney(Player, amount, 'cash', data.comment)
        handleTransaction(data.fromAccount, locale("personal_acc") .. data.fromAccount, amount, data.comment, Player2, name, "withdraw")
        return getBankData(source)
    end
    TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money"))
    return false
end)

lib.callback.register('Renewed-Banking:server:transfer', function(source, data)
    if type(data) ~= "table" then return false end
    local Player = GetPlayerObject(source)
    if not Player then return false end
    local amount = tonumber(data.amount)
    if not amount or amount < 1 then
        Notify(source, {title = locale("bank_name"), description = locale("invalid_amount", "transfer"), type = "error"})
        return false
    end
    if cachedAccounts[data.fromAccount] and not canAccessAccount(source, data.fromAccount) then return rejectUnauthorized(source, data.fromAccount) end
    local name = GetCharacterName(Player)
    if not data.comment or data.comment == "" then data.comment = locale("comp_transaction", name, "transfered", amount) else data.comment = sanitizeMessage(data.comment) end
    if cachedAccounts[data.fromAccount] then
        if cachedAccounts[data.stateid] then
            local canTransfer = RemoveAccountMoney(data.fromAccount, amount)
            if canTransfer then
                AddAccountMoney(data.stateid, amount)
                local title = ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount)
                local transaction = handleTransaction(data.fromAccount, title, amount, data.comment, cachedAccounts[data.fromAccount].name, cachedAccounts[data.stateid].name, "withdraw")
                handleTransaction(data.stateid, title, amount, data.comment, cachedAccounts[data.fromAccount].name, cachedAccounts[data.stateid].name, "deposit", transaction.trans_id)
            else TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money")) return false end
        else
            local Player2 = getPlayerData(source, data.stateid)
            if not Player2 then TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("fail_transfer")) return false end
            local canTransfer = RemoveAccountMoney(data.fromAccount, amount)
            if canTransfer then
                AddMoney(Player2, amount, 'bank', data.comment)
                local plyName = GetCharacterName(Player2)
                local transaction = handleTransaction(data.fromAccount, ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount), amount, data.comment, cachedAccounts[data.fromAccount].name, plyName, "withdraw")
                handleTransaction(data.stateid, ("%s / %s"):format(cachedAccounts[data.fromAccount].name, data.fromAccount), amount, data.comment, cachedAccounts[data.fromAccount].name, plyName, "deposit", transaction.trans_id)
            else TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money")) return false end
        end
    else
        local funds = GetFunds(Player)
        if cachedAccounts[data.stateid] then
            if funds.bank >= amount and RemoveMoney(Player, amount, 'bank', data.comment) then
                AddAccountMoney(data.stateid, amount)
                local transaction = handleTransaction(data.fromAccount, locale("personal_acc") .. data.fromAccount, amount, data.comment, name, cachedAccounts[data.stateid].name, "withdraw")
                handleTransaction(data.stateid, locale("personal_acc") .. data.fromAccount, amount, data.comment, name, cachedAccounts[data.stateid].name, "deposit", transaction.trans_id)
            else TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money")) return false end
        else
            local Player2 = getPlayerData(source, data.stateid)
            if not Player2 then TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("fail_transfer")) return false end
            if funds.bank >= amount and RemoveMoney(Player, amount, 'bank', data.comment) then
                AddMoney(Player2, amount, 'bank', data.comment)
                local name2 = GetCharacterName(Player2)
                local transaction = handleTransaction(data.fromAccount, locale("personal_acc") .. data.fromAccount, amount, data.comment, name, name2, "withdraw")
                handleTransaction(data.stateid, locale("personal_acc") .. data.fromAccount, amount, data.comment, name, name2, "deposit", transaction.trans_id)
            else TriggerClientEvent('Renewed-Banking:client:sendNotification', source, locale("not_enough_money")) return false end
        end
    end
    return getBankData(source)
end)

RegisterNetEvent('Renewed-Banking:server:createNewAccount', function(accountid)
    local Player = GetPlayerObject(source)
    if not Player or type(accountid) ~= 'string' or accountid == '' or #accountid > 50 then return end
    if cachedAccounts[accountid] then return Notify(source, {title = locale("bank_name"), description = locale("account_taken"), type = "error"}) end
    local cid = GetIdentifier(Player)
    if not cachedPlayers[cid] then UpdatePlayerAccount(cid) end
    cachedAccounts[accountid] = {id = accountid, type = locale("org"), name = accountid, frozen = 0, amount = 0, transactions = {}, auth = {[cid] = true}, creator = cid}
    cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = accountid
    MySQL.insert("INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator) VALUES (?, ?, ?, ?, ?, ?) ", {accountid, 0, json.encode({}), json.encode({cid}), 0, cid})
end)

RegisterNetEvent("Renewed-Banking:server:getPlayerAccounts", function()
    local Player = GetPlayerObject(source)
    if not Player then return end
    local cid = GetIdentifier(Player)
    if not cachedPlayers[cid] then UpdatePlayerAccount(cid) end
    local accounts = cachedPlayers[cid].accounts
    local data = {}
    if #accounts >= 1 then
        for k=1, #accounts do
            if cachedAccounts[accounts[k]] and cachedAccounts[accounts[k]].creator == cid then data[#data+1] = accounts[k] end
        end
    end
    TriggerClientEvent("Renewed-Banking:client:accountsMenu", source, data)
end)

RegisterNetEvent("Renewed-Banking:server:viewMemberManagement", function(data)
    if type(data) ~= 'table' then return end
    local Player = GetPlayerObject(source)
    if not Player or not cachedAccounts[data.account] then return end
    local cid = GetIdentifier(Player)
    if cachedAccounts[data.account].creator ~= cid then return rejectUnauthorized(source, data.account) end
    local retData = {account = data.account, members = {}}
    for k,_ in pairs(cachedAccounts[data.account].auth) do
        local Player2 = getPlayerData(source, k)
        if Player2 and cid ~= GetIdentifier(Player2) then retData.members[k] = GetCharacterName(Player2) end
    end
    TriggerClientEvent("Renewed-Banking:client:viewMemberManagement", source, retData)
end)

RegisterNetEvent('Renewed-Banking:server:addAccountMember', function(account, member)
    local Player = GetPlayerObject(source)
    if not Player or not cachedAccounts[account] then return end
    if GetIdentifier(Player) ~= cachedAccounts[account].creator then return rejectUnauthorized(source, account) end
    local Player2 = getPlayerData(source, member)
    if not Player2 then return end
    local targetCID = GetIdentifier(Player2)
    if cachedPlayers[targetCID] then cachedPlayers[targetCID].accounts[#cachedPlayers[targetCID].accounts+1] = account end
    local auth = {}
    for k in pairs(cachedAccounts[account].auth) do auth[#auth+1] = k end
    auth[#auth+1] = targetCID
    cachedAccounts[account].auth[targetCID] = true
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(auth), account})
end)

RegisterNetEvent('Renewed-Banking:server:removeAccountMember', function(data)
    if type(data) ~= 'table' then return end
    local Player = GetPlayerObject(source)
    if not Player or not cachedAccounts[data.account] then return end
    if GetIdentifier(Player) ~= cachedAccounts[data.account].creator then return rejectUnauthorized(source, data.account) end
    local Player2 = getPlayerData(source, data.cid)
    if not Player2 then return end
    local targetCID = GetIdentifier(Player2)
    local tmp = {}
    for k in pairs(cachedAccounts[data.account].auth) do if targetCID ~= k then tmp[#tmp+1] = k end end
    if cachedPlayers[targetCID] then
        local newAccount = {}
        for k=1, #cachedPlayers[targetCID].accounts do if cachedPlayers[targetCID].accounts[k] ~= data.account then newAccount[#newAccount+1] = cachedPlayers[targetCID].accounts[k] end end
        cachedPlayers[targetCID].accounts = newAccount
    end
    cachedAccounts[data.account].auth[targetCID] = nil
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(tmp), data.account})
end)

RegisterNetEvent('Renewed-Banking:server:deleteAccount', function(data)
    if type(data) ~= 'table' then return end
    local account = data.account
    local Player = GetPlayerObject(source)
    if not Player or not cachedAccounts[account] then return end
    local cid = GetIdentifier(Player)
    if cachedAccounts[account].creator ~= cid then return rejectUnauthorized(source, account) end
    cachedAccounts[account] = nil
    if cachedPlayers[cid] then
        for k=1, #cachedPlayers[cid].accounts do
            if cachedPlayers[cid].accounts[k] == account then table.remove(cachedPlayers[cid].accounts, k) break end
        end
    end
    MySQL.update("DELETE FROM `bank_accounts_new` WHERE id=:id", {id = account})
end)

local find = string.find
local sub = string.sub
local function split(str, delimiter)
    local result = {}
    local from = 1
    local delim_from, delim_to = find(str, delimiter, from)
    while delim_from do
        result[#result + 1] = sub(str, from, delim_from - 1)
        from = delim_to + 1
        delim_from, delim_to = find(str, delimiter, from)
    end
    result[#result + 1] = sub(str, from)
    return result
end

local function updateAccountName(account, newName, src)
    if not account or not newName then return false end
    if not cachedAccounts[account] then
        local getTranslation = locale("invalid_account", account)
        print(getTranslation)
        if src then Notify(src, {title = locale("bank_name"), description = split(getTranslation, '0')[2], type = "error"}) end
        return false
    end
    if cachedAccounts[newName] then
        local getTranslation = locale("existing_account", account)
        print(getTranslation)
        if src then Notify(src, {title = locale("bank_name"), description = split(getTranslation, '0')[2], type = "error"}) end
        return false
    end
    if src then
        local Player = GetPlayerObject(src)
        if not Player or GetIdentifier(Player) ~= cachedAccounts[account].creator then
            local getTranslation = locale("illegal_action", GetPlayerName(src))
            print(getTranslation)
            Notify(src, {title = locale("bank_name"), description = split(getTranslation, '0')[2], type = "error"})
            return false
        end
    end
    cachedAccounts[newName] = json.decode(json.encode(cachedAccounts[account]))
    cachedAccounts[newName].id = newName
    cachedAccounts[newName].name = newName
    cachedAccounts[account] = nil
    for _, id in ipairs(GetPlayers()) do
        local Player2 = GetPlayerObject(id)
        if not Player2 then goto Skip end
        local cid = GetIdentifier(Player2)
        if cachedPlayers[cid] and #cachedPlayers[cid].accounts >= 1 then
            for k=1, #cachedPlayers[cid].accounts do
                if cachedPlayers[cid].accounts[k] == account then
                    table.remove(cachedPlayers[cid].accounts, k)
                    cachedPlayers[cid].accounts[#cachedPlayers[cid].accounts+1] = newName
                end
            end
        end
        ::Skip::
    end
    MySQL.update('UPDATE bank_accounts_new SET id = ? WHERE id = ?',{newName, account})
    return true
end

RegisterNetEvent('Renewed-Banking:server:changeAccountName', function(account, newName) updateAccountName(account, newName, source) end)
exports("changeAccountName", updateAccountName)

function GetJobAccount(jobName)
    if type(jobName) ~= "string" or jobName == "" then error(("^5[%s]^7-^1[ERROR]^7 %s"):format(GetInvokingResource(), "Invalid job name: expected a non-empty string")) end
    return cachedAccounts[jobName] or nil
end
exports('GetJobAccount', GetJobAccount)

local function CreateJobAccount(job, initialBalance)
    local currentResourceName = GetInvokingResource()
    if type(job) ~= "table" then error(("^5[%s]^7-^1[ERROR]^7 %s"):format(currentResourceName, "Invalid parameter: expected a table (job)")) end
    if type(job.name) ~= "string" or job.name == "" then error(("^5[%s]^7-^1[ERROR]^7 %s"):format(currentResourceName, "Invalid job name: expected a non-empty string")) end
    if type(job.label) ~= "string" or job.label == "" then error(("^5[%s]^7-^1[ERROR]^7 %s"):format(currentResourceName, "Invalid job label: expected a non-empty string")) end
    if cachedAccounts[job.name] then return cachedAccounts[job.name] end
    cachedAccounts[job.name] = {id = job.name, type = locale("org"), name = job.label, frozen = 0, amount = tonumber(initialBalance) or 0, transactions = {}, auth = {}, creator = nil}
    local success, errorMsg = MySQL.insert("INSERT INTO bank_accounts_new (id, amount, transactions, auth, isFrozen, creator) VALUES (?, ?, ?, ?, ?, NULL)", {job.name, cachedAccounts[job.name].amount, json.encode(cachedAccounts[job.name].transactions), json.encode(cachedAccounts[job.name].auth), cachedAccounts[job.name].frozen})
    if not success then cachedAccounts[job.name] = nil error(("^5[%s]^7-^1[ERROR]^7 %s"):format(currentResourceName, "Database error: " .. tostring(errorMsg))) end
    return cachedAccounts[job.name]
end
exports("CreateJobAccount", CreateJobAccount)

local function addAccountMember(account, member)
    if not account or not member or not cachedAccounts[account] then return end
    local Player2 = getPlayerData(false, member)
    if not Player2 then return end
    local targetCID = GetIdentifier(Player2)
    if cachedPlayers[targetCID] then cachedPlayers[targetCID].accounts[#cachedPlayers[targetCID].accounts+1] = account end
    local auth = {}
    for k in pairs(cachedAccounts[account].auth) do auth[#auth+1] = k end
    auth[#auth+1] = targetCID
    cachedAccounts[account].auth[targetCID] = true
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(auth), account})
end
exports("addAccountMember", addAccountMember)

local function removeAccountMember(account, member)
    local Player2 = getPlayerData(false, member)
    if not Player2 or not cachedAccounts[account] then return end
    local targetCID = GetIdentifier(Player2)
    local tmp = {}
    for k in pairs(cachedAccounts[account].auth) do if targetCID ~= k then tmp[#tmp+1] = k end end
    if cachedPlayers[targetCID] then
        local newAccount = {}
        for k=1, #cachedPlayers[targetCID].accounts do if cachedPlayers[targetCID].accounts[k] ~= account then newAccount[#newAccount+1] = cachedPlayers[targetCID].accounts[k] end end
        cachedPlayers[targetCID].accounts = newAccount
    end
    cachedAccounts[account].auth[targetCID] = nil
    MySQL.update('UPDATE bank_accounts_new SET auth = ? WHERE id = ?',{json.encode(tmp), account})
end
exports("removeAccountMember", removeAccountMember)

local function getAccountTransactions(account)
    if cachedAccounts[account] then return cachedAccounts[account].transactions end
    if cachedPlayers[account] then return cachedPlayers[account].transactions end
    print(locale("invalid_account", account))
    return false
end
exports("getAccountTransactions", getAccountTransactions)

lib.addCommand('givecash', {
    help = 'Gives an item to a player',
    params = {{name = 'target', type = 'playerId', help = locale("cmd_plyr_id")},{name = 'amount', type = 'number', help = locale("cmd_amount")}}
}, function(source, args)
    local Player = GetPlayerObject(source)
    if not Player then return end
    local iPlayer = GetPlayerObject(args.target)
    if not iPlayer then return Notify(source, {title = locale("bank_name"), description = locale('unknown_player', args.target), type = "error"}) end
    if IsDead(Player) then return Notify(source, {title = locale("bank_name"), description = locale('dead'), type = "error"}) end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(args.target))) > 10.0 then return Notify(source, {title = locale("bank_name"), description = locale('too_far_away'), type = "error"}) end
    if args.amount <= 0 then return Notify(source, {title = locale("bank_name"), description = locale('invalid_amount', "give"), type = "error"}) end
    if RemoveMoney(Player, args.amount, 'cash') then
        AddMoney(iPlayer, args.amount, 'cash')
        local nameA = GetCharacterName(Player)
        local nameB = GetCharacterName(iPlayer)
        Notify(source, {title = locale("bank_name"), description = locale('give_cash', nameB, tostring(args.amount)), type = "error"})
        Notify(args.target, {title = locale("bank_name"), description = locale('received_cash', nameA, tostring(args.amount)), type = "success"})
    else
        Notify(source, {title = locale("bank_name"), description = locale('not_enough_money'), type = "error"})
    end
end)

function ExportHandler(resource, name, cb)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB) setCB(cb) end)
end

local createTables = {
    {query = "CREATE TABLE IF NOT EXISTS `bank_accounts_new` (`id` varchar(50) NOT NULL, `amount` int(11) DEFAULT 0, `transactions` longtext DEFAULT '[]', `auth` longtext DEFAULT '[]', `isFrozen` int(11) DEFAULT 0, `creator` varchar(50) DEFAULT NULL, PRIMARY KEY (`id`));", values = nil},
    {query = "CREATE TABLE IF NOT EXISTS `player_transactions` (`id` varchar(50) NOT NULL, `isFrozen` int(11) DEFAULT 0, `transactions` longtext DEFAULT '[]', PRIMARY KEY (`id`));", values = nil}
}
assert(MySQL.transaction.await(createTables), "Failed to create tables")