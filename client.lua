-- client.lua
-- CivDev HUD - Multi-framework (QBCore / ESX / Vanilla)
-- Uses external config.lua and supports multi-fuel export detection.

Config = Config or require 'config'

local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function round(v) return math.floor((v or 0) + 0.5) end

-- Framework detection
local Framework = { name = "none", QBCore = nil, ESX = nil }

Citizen.CreateThread(function()
    if Config.PreferQBCore and GetResourceState('qb-core') == 'started' and exports['qb-core'] then
        local ok, core = pcall(function() return exports['qb-core']:GetCoreObject() end)
        if ok and core then
            Framework.name = "qb"
            Framework.QBCore = core
            print(("^2[%s]^7 Detected QBCore (client) — v%s"):format(Config.ResourceName or GetCurrentResourceName(), Config.Version or '?.?.?'))
        end
    end

    if Framework.name == "none" and GetResourceState('es_extended') == 'started' and exports['es_extended'] then
        local ok, esx = pcall(function() return exports['es_extended']:getSharedObject() end)
        if ok and esx then
            Framework.name = "esx"
            Framework.ESX = esx
            print(("^2[%s]^7 Detected ESX (client) — v%s"):format(Config.ResourceName or GetCurrentResourceName(), Config.Version or '?.?.?'))
        end
    end
end)

-- =========================
-- Fuel helpers (multi-export)
-- =========================
local function tryNormalizeNumeric(val)
    if val == nil then return nil end
    local num = tonumber(val)
    if not num then return nil end

    if num > 0 and num <= 1 and Config.Fuel.PreferFractional then
        return round(num * 100)
    end

    if num >= 0 and num <= 100 then
        return round(num)
    end

    if num > 100 and Config.Fuel.DefaultTankCapacityLiters and Config.Fuel.DefaultTankCapacityLiters > 0 then
        local pct = (num / Config.Fuel.DefaultTankCapacityLiters) * 100
        return clamp(round(pct), 0, 100)
    end

    if num >= 0 and num <= 1 then
        return round(num * 100)
    end

    return clamp(round(num), 0, 100)
end

local function getFuelPercentFromVehicle(veh)
    if not Config.Fuel or not Config.Fuel.Enabled then return nil end
    if not DoesEntityExist(veh) then return nil end

    -- Native
    if GetVehicleFuelLevel then
        local ok, lvl = pcall(function() return GetVehicleFuelLevel(veh) end)
        if ok and lvl ~= nil then
            local n = tryNormalizeNumeric(lvl)
            if n ~= nil then return n end
        end
    end

    -- Configured exports (priority)
    if Config.Fuel.ExportsPriority and type(Config.Fuel.ExportsPriority) == 'table' then
        for _, ex in ipairs(Config.Fuel.ExportsPriority) do
            if ex and ex.name and ex.fn then
                local ok, val = pcall(function()
                    if exports[ex.name] and type(exports[ex.name][ex.fn]) == 'function' then
                        return exports[ex.name][ex.fn](veh)
                    end
                    return nil
                end)
                if ok and val ~= nil then
                    local n = tryNormalizeNumeric(val)
                    if n ~= nil then return n end
                end
            end
        end
    end

    -- Fallback global functions
    local fallbackCandidates = { 'GetFuel', 'getVehicleFuel', 'GetVehicleFuel', 'GetFuelLevel' }
    for _, fnName in ipairs(fallbackCandidates) do
        local ok, val = pcall(function()
            if _G and type(_G[fnName]) == 'function' then
                return _G[fnName](veh)
            end
            return nil
        end)
        if ok and val ~= nil then
            local n = tryNormalizeNumeric(val)
            if n ~= nil then return n end
        end
    end

    return nil
end

-- =========================
-- Status / vitals / vehicle (with fuel)
-- =========================
local function getStatuses()
    local hunger, thirst, stamina = Config.Fallbacks.hunger, Config.Fallbacks.thirst, Config.Fallbacks.stamina

    if Framework.name == "qb" and Framework.QBCore then
        local ok, pd = pcall(function() return Framework.QBCore.Functions.GetPlayerData() end)
        if ok and pd and pd.metadata then
            hunger = pd.metadata.hunger or hunger
            thirst = pd.metadata.thirst or thirst
        end
        if Config.UseStatusExports and exports['qb-status'] and exports['qb-status'].GetStatus then
            local ok2, s = pcall(function() return exports['qb-status']:GetStatus() end)
            if ok2 and s then
                hunger = s.hunger or hunger
                thirst = s.thirst or thirst
            end
        end
    elseif Framework.name == "esx" and Framework.ESX then
        if Config.UseStatusExports and exports['esx_status'] and exports['esx_status'].getStatus then
            local ok, h = pcall(function() return exports['esx_status']:getStatus('hunger') end)
            if ok and h then hunger = h.getPercent and h:getPercent() or h.percent or hunger end
            local ok2, t = pcall(function() return exports['esx_status']:getStatus('thirst') end)
            if ok2 and t then thirst = t.getPercent and t:getPercent() or t.percent or thirst end
        end
        if Framework.ESX.PlayerData and Framework.ESX.PlayerData.metadata then
            local md = Framework.ESX.PlayerData.metadata
            hunger = md.hunger or hunger
            thirst = md.thirst or thirst
        end
    end

    return clamp(hunger, 0, 100), clamp(thirst, 0, 100), clamp(stamina, 0, 100)
end

local function getPlayerVitals()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return 0, 0 end
    local rawHealth = GetEntityHealth(ped) or 0
    local healthPercent = clamp(((rawHealth - 100) / 100) * 100, 0, 100)
    local armor = clamp(GetPedArmour(ped) or 0, 0, 100)
    return round(healthPercent), round(armor)
end

local function getVehicleInfoWithFuel()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        return 0, 0, nil, Config.DefaultSpeedUnit, Config.MaxSpeedDefault, nil
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return 0, 0, nil, Config.DefaultSpeedUnit, Config.MaxSpeedDefault, nil end

    local speed_mps = GetEntitySpeed(veh) or 0
    local speed_kmh = speed_mps * 3.6
    local speed_mph = speed_mps * 2.2369362921
    local unit = Config.DefaultSpeedUnit
    local speed = (unit == "MPH") and round(speed_mph) or round(speed_kmh)

    local gear = nil
    if GetVehicleCurrentGear and type(GetVehicleCurrentGear) == "function" then
        local g = GetVehicleCurrentGear(veh)
        if g and g ~= 0 then gear = g end
    end

    local rpmPct = 0
    if GetVehicleCurrentRpm and type(GetVehicleCurrentRpm) == "function" then
        local rpm = GetVehicleCurrentRpm(veh) or 0
        rpmPct = clamp(round(rpm * 100), 0, 100)
    end

    local maxSpeed = Config.MaxSpeedDefault

    local fuelPct = nil
    if Config.Fuel and Config.Fuel.Enabled then
        local ok, val = pcall(function() return getFuelPercentFromVehicle(veh) end)
        if ok and val ~= nil then fuelPct = clamp(val, 0, 100) end
    end

    return speed, rpmPct, gear, unit, maxSpeed, fuelPct
end

-- Speaking & server ID
local function isPlayerSpeaking()
    return NetworkIsPlayerTalking(PlayerId())
end

local forcedServerId = nil
RegisterNetEvent('civDev:setServerId', function(id) forcedServerId = id end)
Citizen.CreateThread(function()
    Wait(1500)
    TriggerServerEvent('civDev:requestServerId')
end)

-- Print client startup
print(("^2[%s]^7 client v%s loaded."):format(Config.ResourceName or GetCurrentResourceName(), Config.Version or '?.?.?'))

-- Main loop
Citizen.CreateThread(function()
    while true do
        local health, armor = getPlayerVitals()
        local hunger, thirst, stamina = getStatuses()
        local speed, rpmPct, gear, unit, maxSpeed, fuel = getVehicleInfoWithFuel()
        local speaking = isPlayerSpeaking()
        local serverId = forcedServerId or GetPlayerServerId(PlayerId())

        local payload = {
            health = health,
            armor = armor,
            hunger = hunger,
            thirst = thirst,
            stamina = stamina,
            speed = speed,
            rpm = rpmPct,
            currentGear = gear,
            speedUnit = unit,
            maxSpeed = maxSpeed,
            fuel = fuel,
            speaking = speaking,
            serverId = serverId
        }

        SendNUIMessage({ action = 'update', payload = payload })
        Citizen.Wait(Config.UpdateInterval)
    end
end)
