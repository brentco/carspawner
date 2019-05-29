RegisterNetEvent("carspawner:spawnVehicleRequest") -- spawns a vehicle commanded by the server
RegisterNetEvent("carspawner:occupationCheckRequest") -- will check if a vehicle exists and sends the result back to the server
RegisterNetEvent("playerConnected")
function DebugLine(message)

end

-- #region info
function informServerOfSpawn(requestHandle, result)
    TriggerServerEvent("carspawner:spawnInfo", requestHandle, result)
end

function informServerOfPresence(requestHandle, result)
    DebugLine("Informing server " .. tostring(result))
    TriggerServerEvent("carspawner:vehicleOccupationCheckResult", requestHandle, result)
end
-- #endregion

-- #region handlers
AddEventHandler("carspawner:spawnVehicleRequest", function(requestHandle, vehicleHash, x, y, z, heading)
    DebugLine("Received spawn request. Handle = " .. requestHandle .. ", hash = " .. vehicleHash .. ", x = " .. x .. ", y = " .. y .. ", z = " .. z .. ", heading = " .. heading)
    Citizen.CreateThread(function()
        RequestModel(vehicleHash)
        while not HasModelLoaded(vehicleHash) do
            Citizen.Wait(0)
        end
        CreateVehicle(vehicleHash, x, y, z, heading, true, true)
    end)
end)

AddEventHandler("carspawner:occupationCheckRequest", function(requestHandle, vehicleName, x, y, z, radius)
    DebugLine("Received check request for " .. vehicleName .. " request handle = " .. requestHandle .. ", x = " .. x .. ", y = " .. y .. ", z = " .. z .. ", radius = " .. radius)
    local result = IsAnyVehicleNearPoint(x, y, z, radius * 1.0)
    DebugLine("Check = " .. tostring(result))
    informServerOfPresence(requestHandle, result)
end)

Citizen.CreateThread(function()
    while true do
      Citizen.Wait(0)
      if NetworkIsSessionActive() then TriggerServerEvent('playerConnected') return end
    end
  end)
-- #endregion
