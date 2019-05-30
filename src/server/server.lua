-- Write spawns here
local spawnDefinitions = {
    {vehicleName = "airtug", x = -54.26639938354492, y = -1679.548828125, z = 30.4414, heading = 228.2736053466797, cooldownInSeconds = 10, occupationRadius = 10}
}

-- Constants
local ERROR = 5
local WARN = 4
local INFO = 3
local DEBUG = 2
local TRACE = 1

-- Script settings
local DEBUG_LEVEL = TRACE

-- Do not modify
local spawnedCarMap = {}
local pendingRequests = {}
local handleCounter = 0
local chosenUserForSpawning
local hasLoaded = false

local players  = { }

RegisterNetEvent("carspawner:vehicleOccupationCheckResult")

---Selects the first player found currently online to use as spawner client. If none is found, it's reset to nil.
function selectPlayer()
    log(LogLevel.DEBUG, "players: %s", dump(players))
    for k, v in pairs(players) do
        log(LogLevel.DEBUG, "select player pair: k = %s, v = %s", k, v)
        if v ~= nil then
            chosenUserForSpawning = k
            return
        end
    end

    chosenUserForSpawning = nil
end

---@param level number
---@param message string
function log(level, message)
    if level < DEBUG_LEVEL then
        return
    end

    local sw = {
        [TRACE] = function(msg) print("[TRACE] " .. msg) end,
        [DEBUG] = function(msg) print("[DEBUG] " .. msg) end,
        [INFO] = function(msg) print("[INFO] " .. msg) end,
        [WARN] = function(msg) print("[WARN] " .. msg) end,
        [ERROR] = function(msg) print("[ERROR] " .. msg) end
    }

    if sw[level] ~= nil then
        sw[level](message)
    end
end

--- Gives a unique handler but restarts from 1 if it becomes too large.
function NewHandle()
    if handleCounter >= 1000000 then
        handleCounter = 0
    end
    handleCounter = handleCounter + 1
    return handleCounter
end

function GetFirstAvailablePlayer()
    return chosenUserForSpawning
end

function SpawnVehicle(spawnData)
    local handle = NewHandle()
    local def = spawnData.definition
    local playerId = GetFirstAvailablePlayer()
    if playerId == nil then
        log(WARN, "Could not spawn vehicle because no players are connected.")
        return false
    end
    TriggerClientEvent("carspawner:spawnVehicleRequest", playerId, handle, def.vehicleHash, def.x, def.y, def.z, def.heading)
    return true
end

function RequestOccupationCheck(spawnData)
    local playerId = GetFirstAvailablePlayer()
    if playerId == nil then
        log(WARN, "Could not request player check because no players are connected.")
        return
    end
    spawnData.hasPendingCheck = true
    local def = spawnData.definition
    local handle = NewHandle()
    log(TRACE, "Check request: handle = " .. handle .. ", name = " .. def.vehicleName .. ", x = " .. def.x .. ", y = ".. def.y ..", z = "..def.z..", radius = " .. def.occupationRadius)
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
        log(TRACE, "No player available for spawn.")
        return
    end

    if not spawnData.spawned then
        log(DEBUG, "Initial spawn of vehicle " .. spawnData.definition.vehicleName)
        spawnData.spawned = SpawnVehicle(spawnData)
        log(DEBUG, "Success? " .. tostring(spawnData.spawned))
        return
    end

    if spawnData.hasPendingCheck then
        log(TRACE, "Check pending for vehicle " .. spawnData.vehicleName)
        return
    end

    if spawnData.isVehicleDisplaced then
        local currentTime = getTime()
        local timeElapsedSinceDisplacement = currentTime - spawnData.displacedTimestamp

        if timeElapsedSinceDisplacement >= spawnData.definition.cooldownInSeconds then
            log(DEBUG, "Respawning vehicle " .. spawnData.definition.vehicleName)
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
        while true do
            for i = 1, #spawnedCarMap do
                local spawnData = spawnedCarMap[i]
                log(TRACE, "Checking " .. spawnData.definition.vehicleName)
                CheckSpawn(spawnData)
            end
            Citizen.Wait(1000)
        end
    end)
end

AddEventHandler("carspawner:vehicleOccupationCheckResult", function(handle, occupied)
    if pendingRequests[handle] == nil then
        log(DEBUG, "Received an unexpected handle in result: " .. tostring(handle) .. ". Discarding it.")
        return
    end

    local spawnData = pendingRequests[handle].spawnData
    log(DEBUG, "Received check result for vehicle " .. spawnData.definition.vehicleName .. " and occupied: " .. tostring(occupied))
    spawnData.hasPendingCheck = false
    pendingRequests[handle] = nil
    if occupied then
        spawnData.isVehicleDisplaced = false
        spawnData.displacedTimestamp = nil
    else
        if not spawnData.isVehicleDisplaced then
            spawnData.isVehicleDisplaced = true
            spawnData.displacedTimestamp = getTime()
            log(DEBUG, "Vehicle " .. spawnData.definition.vehicleName .. " displaced on " .. spawnData.displacedTimestamp)
        end
    end
end)

AddEventHandler('playerConnected', function()
    local player = source
    log(DEBUG, "Player with ID " .. player .. " connected.")
    players[player] = true
    --if chosenUserForSpawning == nil then
        selectPlayer()
    --end

    if not hasLoaded then
        log(LogLevel.DEBUG, "Initializing spawns upon first player connect")
        hasLoaded = true
        loadDefinitions()
        StartScheduledCheck()
    end
end)
AddEventHandler('playerDropped', function(player)
    log(DEBUG, "Player with ID " .. player .. " disconnected.")
    players[player] = nil
    selectPlayer()
end)
