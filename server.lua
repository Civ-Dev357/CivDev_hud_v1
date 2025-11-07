local forcedHUD = {} 

local cfg = Config or (LoadResourceFile(GetCurrentResourceName(), 'config.lua') and (function() return require('config') end)() )
local resourceName = (cfg and cfg.ResourceName) or GetCurrentResourceName()
local resourceVersion = (cfg and cfg.Version) or '?.?.?'

AddEventHandler('onResourceStart', function(resourceNameStarted)
    if resourceNameStarted == GetCurrentResourceName() then
        print(("^1[%s]^7 v%s started on server."):format(resourceName, resourceVersion))
    end
end)

RegisterNetEvent('civDev:requestServerId', function()
    local src = source
    if not src or src == 0 then return end
    local sid = GetPlayerServerId(src)
    local idToSend = forcedHUD[sid] or sid
    TriggerClientEvent('civDev:setServerId', src, idToSend)
end)

RegisterCommand('sethudid', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command') then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[CivDev]^7', 'You lack permission for this command.' } })
        return
    end

    local target = tonumber(args[1])
    local hudId = tonumber(args[2])

    if not target or not hudId then
        local usage = 'Usage: /sethudid <playerId> <hudId>'
        if source == 0 then print(usage)
        else TriggerClientEvent('chat:addMessage', source, { args = { '^3[CivDev]^7', usage } }) end
        return
    end

    forcedHUD[target] = hudId
    TriggerClientEvent('civDev:setServerId', target, hudId)

    local msg = ('[CivDev] Set HUD ID for %s → %s'):format(target, hudId)
    if source == 0 then print(msg)
    else TriggerClientEvent('chat:addMessage', source, { args = { '^2[CivDev]^7', msg } }) end
end, true)

RegisterCommand('cleanhudid', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command') then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[CivDev]^7', 'You lack permission for this command.' } })
        return
    end

    local target = tonumber(args[1])
    if not target then
        local usage = 'Usage: /cleanhudid <playerId>'
        if source == 0 then print(usage)
        else TriggerClientEvent('chat:addMessage', source, { args = { '^3[CivDev]^7', usage } }) end
        return
    end

    forcedHUD[target] = nil
    TriggerClientEvent('civDev:setServerId', target, GetPlayerServerId(target))

    local msg = ('[CivDev] Cleared HUD ID override for %s'):format(target)
    if source == 0 then print(msg)
    else TriggerClientEvent('chat:addMessage', source, { args = { '^2[CivDev]^7', msg } }) end
end, true)

RegisterCommand('broadcasthud', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command') then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1[CivDev]^7', 'You lack permission for this command.' } })
        return
    end

    local hudId = tonumber(args[1])
    if not hudId then
        local usage = 'Usage: /broadcasthud <hudId>'
        if source == 0 then print(usage)
        else TriggerClientEvent('chat:addMessage', source, { args = { '^3[CivDev]^7', usage } }) end
        return
    end

    for _, pid in ipairs(GetPlayers()) do
        local p = tonumber(pid)
        if p then TriggerClientEvent('civDev:setServerId', p, hudId) end
    end

    local msg = ('[CivDev] Broadcasted HUD ID %s to all players'):format(hudId)
    if source == 0 then print(msg)
    else TriggerClientEvent('chat:addMessage', source, { args = { '^2[CivDev]^7', msg } }) end
end, true)
