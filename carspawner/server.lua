RegisterNetEvent("carspawner:vehicleOccupationCheckResult")

-- Put vehicle modifiers here
function modifyAirtug(vehicle)
    if vehicle == nil then return end
    SetVehicleEnginePowerMultiplier(vehicle, 4)
end

-- Write spawns here
local spawnDefinitions = {
    {vehicleName = "airtug", x = -54.26639938354492, y = -1679.548828125, z = 30.4414, heading = 228.2736053466797, cooldownInSeconds = 10, occupationRadius = 10, modifier = modifyAirtug}
}

-- Do not modify
local spawnedCarMap = {}
local pendingRequests = {}
local handleCounter = 0
local chosenUserForSpawning = nil
local hasLoaded = false

function DebugLine(message)

end

-- Gives a unique handler but restarts from 1 if it becomes too large.
function NewHandle()
    if handleCounter >= 1000000 then
        handleCounter = 0
    end
    handleCounter = handleCounter + 1
    return handleCounter
end

function GetFirstAvailablePlayer()
    return GetPlayers()[1]
end

function SpawnVehicle(spawnData)
    local handle = NewHandle()
    local def = spawnData.definition
    local playerId = GetFirstAvailablePlayer()
    if playerId == nil then
        print("Could not spawn vehicle because no players are connected.")
        return false
    end
    TriggerClientEvent("carspawner:spawnVehicleRequest", playerId, handle, def.vehicleHash, def.x, def.y, def.z, def.heading)
    return true
end

function RequestOccupationCheck(spawnData)
    local playerId = GetFirstAvailablePlayer()
    if playerId == nil then
        print("Could not request player check because no players are connected.")
        return
    end
    spawnData.hasPendingCheck = true
    local def = spawnData.definition
    local handle = NewHandle()
    DebugLine("Check request: handle = " .. handle .. ", name = " .. def.vehicleName .. ", x = " .. def.x .. ", y = ".. def.y ..", z = "..def.z..", radius = " .. def.occupationRadius)
    TriggerClientEvent("carspawner:occupationCheckRequest", playerId, handle, def.vehicleName, def.x, def.y, def.z, def.occupationRadius)
    pendingRequests[handle] = {spawnData = spawnData}
end

function CreateSpawn(def)
    local spawnData = {definition = def, spawned = false, isVehicleDisplaced = false, displacedTimestamp = nil}
    table.insert(spawnedCarMap, spawnData)
    return spawnData
end

function GetTime()
    return os.time(os.date("!*t"))
end

function CheckSpawn(spawnData)
    if GetFirstAvailablePlayer() == nil then
        print("No player available.")
        return
    end

    if not spawnData.spawned then
        print("Initial spawn of vehicle " .. spawnData.definition.vehicleName)
        spawnData.spawned = SpawnVehicle(spawnData)
        print("Success? " .. tostring(spawnData.spawned))
        return
    end

    if spawnData.hasPendingCheck then
        --print("Vehicle has pending check")
        return
    end

    if spawnData.isVehicleDisplaced then
        local currentTime = GetTime()
        local timeElapsedSinceDisplacement = currentTime - spawnData.displacedTimestamp

        if timeElapsedSinceDisplacement >= spawnData.definition.cooldownInSeconds then
            print("Respawning vehicle " .. spawnData.definition.vehicleName)
            local spawned = SpawnVehicle(spawnData)
            if spawned then
                spawnData.displacedTimestamp = nil
                spawnData.isVehicleDisplaced = false
            end
        end
    end

    RequestOccupationCheck(spawnData)
end

function ProcessDefinition(def)
    -- Validate definition
    if def.vehicleName == nil then
        error("Vehicle name is a required parameter.")
        return
    end

    if def.x == nil or def.y == nil or def.z == nil then
        error("X, Y and Z parameters are required.")
        return
    end

    if def.heading == nil then
        def.heading = 0
    end

    if def.cooldownInSeconds == nil then
        def.cooldownInSeconds = 0
    end

    if def.occupationRadius == nil then
        def.occupationRadius = 10
    end

    --[[if not IsModelInCdimage(def.vehicleName) or not IsModelAVehicle(def.vehicleName) then
        error("Vehicle '" .. def.vehicleName .. "' is not a known vehicle.")
        return
    end]]

    def.vehicleHash = GetHashKey(def.vehicleName)

    -- Get to spawn
    local spawnData = CreateSpawn(def)
end

function LoadDefinitions()
    for i = 1, #spawnDefinitions do
        ProcessDefinition(spawnDefinitions[i])
    end
end

function StartScheduledCheck()
    Citizen.CreateThread(function()
        --print("Running check")
        while true do
            for i = 1, #spawnedCarMap do
                local spawnData = spawnedCarMap[i]
                --print("Checking " .. spawnData.definition.vehicleName)
                CheckSpawn(spawnData)
            end
            Citizen.Wait(1000)
        end
    end)
end

AddEventHandler("carspawner:vehicleOccupationCheckResult", function(handle, occupied)
    if pendingRequests[handle] == nil then
        print("Received an unexpected handle in result: " .. tostring(handle) .. ". Discarding it.")
        return
    end

    local spawnData = pendingRequests[handle].spawnData
    DebugLine("Received check result for vehicle " .. spawnData.definition.vehicleName .. " and occupied: " .. tostring(occupied))
    spawnData.hasPendingCheck = false
    pendingRequests[handle] = nil
    if occupied then
        spawnData.isVehicleDisplaced = false
        spawnData.displacedTimestamp = nil
    else
        if not spawnData.isVehicleDisplaced then
            spawnData.isVehicleDisplaced = true
            spawnData.displacedTimestamp = GetTime()
            print("Vehicle " .. spawnData.definition.vehicleName .. " displaced on " .. spawnData.displacedTimestamp)
        end
    end
end)

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    if not hasLoaded then
        hasLoaded = true
        LoadDefinitions()
        StartScheduledCheck()
    end
end)

if GetFirstAvailablePlayer() ~= nil and not hasLoaded then
    hasLoaded = true
    LoadDefinitions()
    StartScheduledCheck()
end
