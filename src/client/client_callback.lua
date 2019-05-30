LOGGING_LEVEL = LogLevel.INFO

local rpcWhitelist = {
    IsAnyVehicleNearPoint = {},
    SetVehicleFuelLevel = {},
    SetVehicleEngineTemperature = {},
    SetVehicleEngineHealth = {},
    SetVehicleDoorOpen = {},
    SetVehicleEngineOn = {},
    SetVehicleDirtLevel = {},
    isValidVehicle = {},
    spawnVehicle = { async = true },
    SetVehicleLights = {},
    DrawMarker = {},
    findClosestVehicle = {},
    SetVehicleIndicatorLights = {},
    SetVehicleColours = {}
}

RegisterNetEvent("carspawner:rpc")

AddEventHandler("carspawner:rpc", function(handle, method, ...)
    log(LogLevel.DEBUG, "RPC request received: handle = %s, method = %s, args = %s", handle, method, dump(...))
    if rpcWhitelist[method] == nil then
        log(LogLevel.WARN, "Method '%s' is not allowed.", method)
        TriggerServerEvent("carspawner:callback", handle, false, "Method '" .. method .. "' is not allowed.")
        return
    end
    if _G[method] == nil then
        log(LogLevel.ERROR, "Method '%s' was not found in global context.", method)
        TriggerServerEvent("carspawner:callback", handle, false, "Method '" .. method .. "' was not found in context.")
        return
    end
    if rpcWhitelist[method].async then
        table.insert(..., 1, handle)
    end
    local varargs = table.unpack(...)
    local originalArgs = ...
    local returnValue
    local pcallResult, err = pcall(function()
        if rpcWhitelist[method].async then
            log(LogLevel.DEBUG, "async method: %s", dump(originalArgs))
            returnValue = _G[method](table.unpack(originalArgs))
        else
            log(LogLevel.DEBUG, "sync method: %s", dump(originalArgs))
            returnValue = _G[method](table.unpack(originalArgs))
        end
    end)
    if not rpcWhitelist[method].async then
        if pcallResult then
            if returnValue == nil then
                log(LogLevel.DEBUG, "Sending response for handle %s: returnValue = nil", handle)
                TriggerServerEvent("carspawner:callback", handle, true)
            else
                log(LogLevel.DEBUG, "Sending response for handle %s: returnValue = %s", handle, returnValue)
                TriggerServerEvent("carspawner:callback", handle, true, returnValue)
            end
        else
            TriggerServerEvent("carspawner:callback", handle, false, err)
        end
    end
end)

function isValidVehicle(vehicleName)
    return IsModelInCdimage(vehicleName) and IsModelAVehicle(vehicleName)
end

function spawnVehicle(handle, vehicleHash, x, y, z, heading)
    log(LogLevel.DEBUG, "Handle = %s, Hash = %s, x = %s, y = %s, z = %s, heading = %s", handle, tostring(vehicleHash), tostring(x), tostring(y), tostring(z), tostring(heading))
    Citizen.CreateThread(function()
        RequestModel(vehicleHash)
        while not HasModelLoaded(vehicleHash) do
            Citizen.Wait(0)
        end
        local vId = CreateVehicle(vehicleHash, x * 1.0, y * 1.0, z * 1.0, heading * 1.0, true, true)
        --CreateVehicle(vehicleHash, -54.26639938354492, -1679.548828125, 30.4414, 228.2736053466797)
        TriggerServerEvent("carspawner:callback", handle, true, vId)
    end)
end

function findClosestVehicle(hash, x, y, z, radius)
    return GetClosestVehicle(x, y, z, radius * 1.0, hash, 70)
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if NetworkIsSessionActive() then
            TriggerServerEvent('playerConnected')
            return
        end
    end
end)