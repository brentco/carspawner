SpawnDefinitions = {
    { vehicleName = "cheetah2",
      x = -54.26639938354492, y = -1679.548828125, z = 30.4414, heading = 228.2736053466797,
      minCooldownInSeconds = 60, maxCooldownInSeconds = 120, checkRadius = 10,
      modifier = function(vehicle)
          --mod(VehicleModifiers.EngineOn, vehicle, false, true, false)
          --mod(VehicleModifiers.Lights, vehicle, 2)
          mod(VehicleModifiers.DirtLevel, vehicle, 14.99)
          mod(VehicleModifiers.EngineHealth, vehicle, 300)
          mod(VehicleModifiers.DoorOpen, vehicle, 4, false, false)
          mod(VehicleModifiers.VehicleColours, vehicle, 55, 131)
          mod(VehicleModifiers.FuelLevel, vehicle, 0)
      end
    }
}