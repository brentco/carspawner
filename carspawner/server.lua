-- Put vehicle modifiers here
function modifyAirtug(vehicle)
end

-- Write spawns here
local spawnDefinitions = {
    {vehicleName = "airtug", x = 100, y = 100, z = 100, heading = 100, cooldownInSeconds = 10, modifier = modifyAirtug}
}

-- Do not modify
local spawnedCarMap = {}
local pendingRequests = {}
local handleCounter = 0
local chosenUserForSpawning = nil
local hasLoaded = false

-- Gives a unique handler but restarts from 1 if it becomes too large.
function NewHandle()
    if handleCounter >= 1000000 then
        handleCounter = 0
    end
    handleCounter = handleCounter + 1
    return handleCounter
end

function ProcessDefinition(def)
    -- Validate definition
    if def.vehicleName == nil then
        error("Vehicle name is a required parameter.")
    end

    if def.x == nil or def.y == nil or def.z == nil then
        error("X, Y and Z parameters are required.")
    end

    if def.heading == nil then
        def.heading = 0
    end

    if def.cooldownInSeconds == nil then
        def.cooldownInSeconds = 0
    end
end

function LoadDefinitions()
    for i = 1, #spawnDefinitions do
        
    end
end

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == "carspawner" and not hasLoaded then
        hasLoaded = true
        LoadDefinitions()
    end
end)