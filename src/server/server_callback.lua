LOGGING_LEVEL = LogLevel.INFO
CHECK_INTERVAL = 2000

local pendingRequests = {}
local handleCounter = 0
local chosenUserForSpawning
local players = {}
local spawnStates = {}

RegisterNetEvent("playerConnected")

--- Gives a unique handler but restarts from 1 if it becomes too large.
function newHandle()
    if handleCounter >= 1000000 then
        handleCounter = 0
    end
    handleCounter = handleCounter + 1
    return handleCounter
end

---Selects the first player found currently online to use as spawner client. If none is found, it's reset to nil.
function selectPlayer()
    log(LogLevel.DEBUG, "players: %s", dump(players))
    for k, v in pairs(players) do
        if v ~= nil then
        log(LogLevel.DEBUG, "select player pair: k = %s, v = %s", k, v)
            chosenUserForSpawning = k
            return
        end
    end

    log(LogLevel.DEBUG, "Erasing chosen player.")
    chosenUserForSpawning = nil
end

RegisterNetEvent("carspawner:callback")
AddEventHandler("carspawner:callback", function(requestHandle, success, data)
    log(LogLevel.TRACE, "Handle: %s, success = %s, data = %s", requestHandle, success, tostring(data))
    if pendingRequests[requestHandle] == nil then
        log(LogLevel.DEBUG, "Received an unexpected request handle (= %s) that will be discarded. Success = %s, data = %s", requestHandle, success, dump(data))
        return
    end

    local req = pendingRequests[requestHandle]
    pendingRequests[requestHandle] = nil
    if req ~= nil then
        if success and req.successCallback ~= nil then
            req.successCallback(data)
        else
            if not success and req.failureCallback ~= nil then
                req.failureCallback(data)
            end
        end
    end
end)

function processDefinition(def)
    -- Validate definition
    if def.vehicleName == nil then
        log(LogLevel.ERROR, "Vehicle name is a required parameter.")
        return
    end

    if def.x == nil or def.y == nil or def.z == nil then
        log(LogLevel.ERROR, "X, Y and Z parameters are required.")
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

    def.vehicleHash = GetHashKey(def.vehicleName)

    -- Get to spawn
    local spawnState = { def = def, spawned = false, isVehicleDisplaced = false, displacedTimestamp = nil }
    table.insert(spawnStates, spawnState)
end

function getTime()
    return os.time(os.date("!*t"))
end

--cooldownTimeModifier = math.ceil(CHECK_INTERVAL / (CHECK_INTERVAL / 1000))

function checkSpawn(spawnState)
    if chosenUserForSpawning == nil then
        log(LogLevel.TRACE, "No player available for spawn.")
        return
    end

    performRpcCall(chosenUserForSpawning, "IsAnyVehicleNearPoint", function(occupied)
        if not spawnState.spawned then
            if occupied then
                log(LogLevel.DEBUG, "Trying to spawn vehicle %s but spawn location is occupied.", spawnState.def.vehicleName)
                performRpcCall(chosenUserForSpawning, "findClosestVehicle", function(vehId)
                    log(LogLevel.DEBUG, "A vehicle of the same type is already present: ID = %s", vehId)
                    spawnState.spawned = true
                    if spawnState.def.modifier ~= nil then
                        spawnState.def.modifier(vehId)
                    end
                end, function(error)
                    log(LogLevel.ERROR, "Failed finding closest vehicle: ", error)
                end, spawnState.def.vehicleHash, spawnState.def.x, spawnState.def.y, spawnState.def.z, spawnState.def.occupationRadius)
                return
            end
            performRpcCall(chosenUserForSpawning, "spawnVehicle", function(vehicleId)
                spawnState.spawned = true
                if spawnState.def.modifier ~= nil then
                    spawnState.def.modifier(vehicleId)
                end
            end, function(error)
                log(LogLevel.ERROR, "Failed spawning vehicle: %s", error)
            end, spawnState.def.vehicleHash, spawnState.def.x, spawnState.def.y, spawnState.def.z, spawnState.def.heading)
        else
            if not spawnState.isVehicleDisplaced and not occupied then
                local displacementTime = getTime()
                spawnState.chosenCooldown = math.random(spawnState.def.minCooldownInSeconds, spawnState.def.maxCooldownInSeconds)
                log(LogLevel.DEBUG, "Vehicle '%s' was moved out of check radius. Marking as displaced since %s and will respawn in %s seconds.", spawnState.def.vehicleName, displacementTime, spawnState.chosenCooldown)
                spawnState.isVehicleDisplaced = true
                spawnState.displacedTimestamp = displacementTime
            else
                if spawnState.isVehicleDisplaced then
                    local elapsedTime = getTime() - spawnState.displacedTimestamp
                    local cooldown = spawnState.chosenCooldown
                    log(LogLevel.DEBUG, "Time elapsed: %s, Cooldown: %s", elapsedTime, cooldown)
                    if elapsedTime >= cooldown then
                        performRpcCall(chosenUserForSpawning, "spawnVehicle", function(vehicleId)
                            log(LogLevel.DEBUG, "Vehicle '%s' respawned", spawnState.def.vehicleName)
                            spawnState.isVehicleDisplaced = false
                            spawnState.displacedTimestamp = nil
                            if spawnState.def.modifier ~= nil then
                                spawnState.def.modifier(vehicleId)
                            end
                        end, function(error)
                            log(LogLevel.ERROR, "Failed spawning vehicle: %s", error)
                        end, spawnState.def.vehicleHash, spawnState.def.x, spawnState.def.y, spawnState.def.z, spawnState.def.heading)
                    end
                end
            end
        end
    end, function(error)
        log(LogLevel.ERROR, "Failed checking occupation: %s", error)
    end, spawnState.def.x, spawnState.def.y, spawnState.def.z, spawnState.def.occupationRadius * 1.0)
end

function loadDefinitions()
    for i = 1, #SpawnDefinitions do
        processDefinition(SpawnDefinitions[i])
    end
end

function startScheduledCheck()
    Citizen.CreateThread(function()
        log(LogLevel.DEBUG, "Check interval set to %s seconds", CHECK_INTERVAL / 1000)
        while true do
            for i = 1, #spawnStates do
                local state = spawnStates[i]
                checkSpawn(state)
            end
            Citizen.Wait(CHECK_INTERVAL)
        end
    end)
end

function performRpcCall(client, rpcName, successCallback, failureCallback, ...)
    if client == nil then
        log(LogLevel.ERROR, "Cannot perform RPC call because client is nil. rpcName = %s", rpcName)
        return
    end
    local handle = newHandle()
    log(LogLevel.TRACE, "Invoking RPC call to client: handle = %s, client = %s, rpcName = %s, args = %s", handle, client, rpcName, dump({ ... }))
    TriggerClientEvent("carspawner:rpc", client, handle, rpcName, { ... })
    pendingRequests[handle] = { type = RequestType.RpcCall, successCallback = successCallback, failureCallback = failureCallback }
end

function performVoidRpcCall(client, rpcName, ...)
    if client == nil then
        log(LogLevel.ERROR, "Cannot perform RPC call because client is nil. rpcName = %s", rpcName)
        return
    end
    local handle = newHandle()
    log(LogLevel.TRACE, "Invoking RPC call to client: handle = %s, client = %s, rpcName = %s, args = %s", handle, client, rpcName, dump({ ... }))
    TriggerClientEvent("carspawner:rpc", client, handle, rpcName, { ... })
    pendingRequests[handle] = { type = RequestType.RpcCall }
end

function mod(modifier, ...)
    performRpcCall(chosenUserForSpawning, modifier.rpcName, function(data)
        log(LogLevel.DEBUG, "Modification (%s) to vehicle was successful. Data = %s", modifier.rpcName, dump(data))
    end, function(error)
        log(LogLevel.ERROR, "Failed modifying car: %s", error)
    end, ...)
end

AddEventHandler('playerConnected', function()
    local player = source
    log(LogLevel.DEBUG, "Player with ID " .. player .. " connected.")
    players[player] = true
    if chosenUserForSpawning == nil then
        selectPlayer()
    end

    if not hasLoaded then
        log(LogLevel.DEBUG, "Initializing spawns upon first player connect")
        hasLoaded = true
        loadDefinitions()
        startScheduledCheck()
    end
end)
AddEventHandler('playerDropped', function(reason)
    local player = source
    log(LogLevel.DEBUG, "Player with ID " .. player .. " disconnected.")
    players[player] = nil
    selectPlayer()
end)
