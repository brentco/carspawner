---Represents an enum of request types.
---@type table
RequestType = {
    SpawnVehicle = {}, -- Used to spawn vehicles
    VerifyVehicleName = {}, -- Used to check if a vehicle name exists (to prevent misconfiguration and thus clients crashing)
    CheckOccupation = {}, -- Used to check an area for vehicles
    RpcCall = {}, -- Used as a result for an rpc call
    ModVehicle = {} -- Used to modify vehicle properties in the client
}

VehicleModifiers = {
    DirtLevel = { rpcName = "SetVehicleDirtLevel", params = { "number" } },
    EngineHealth = { rpcName = "SetVehicleEngineHealth", params = { "number" } },
    FuelLevel = { rpcName = "SetVehicleFuelLevel", params = { "number", "number" } },
    EngineOn = { rpcName = "SetVehicleEngineOn", params = { "number", "boolean", "boolean", "boolean" } },
    Lights = { rpcName = "SetVehicleLights", params = { "number", "number" } },
    DoorOpen = { rpcName = "SetVehicleDoorOpen", params = { "number", "number", "boolean", "boolean" } },
    IndicatorLights = { rpcName = "SetVehicleIndicatorLights", params = { "number", "number", "boolean" } },
    VehicleColours = { rpcName = "SetVehicleColours", params = { "number", "number", "number" } }
}