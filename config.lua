-- config.lua
Config = {}

-- Resource identity
Config.ResourceName = "CivDev_hud_v1"
Config.Version = "1.2.1"

-- Core settings
Config.UpdateInterval = 150
Config.DefaultSpeedUnit = "KM/H"
Config.UseStatusExports = true
Config.Fallbacks = { hunger = 50, thirst = 50, stamina = 100 }
Config.MaxSpeedDefault = 260
Config.PreferQBCore = true

-- Fuel configuration
Config.Fuel = {
  Enabled = true,
  ExportsPriority = {
    { name = 'LegacyFuel', fn = 'GetFuel' },
    { name = 'renzu_fuel', fn = 'getVehicleFuel' },
    { name = 'np-fuel', fn = 'GetFuel' },
    { name = 'ox_fuel', fn = 'GetFuelLevel' },
  },
  DefaultTankCapacityLiters = nil,
  PreferFractional = true,
  FallbackSendValue = nil
}

return Config
