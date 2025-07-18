--HUD update periods (frequencies) in msec, better if slightly different so they don't overlap and cause minor lag spikes. It turns out that threads are relatively synced :D
local PlayerInfoUpdatePeriod = 1000 -- default - 1000; Updates player status - health, hunger (high cpu)
local GPSUpdatePeriod = 440 -- high - 110, medium - 220, low - 440, default - 440 Updates the street you're on (the left side of the hud) (high cpu)
local VehicleSpeedometerUpdatePeriod = 100 -- high value - 100, medium - 230, low - 460, default - 100; Updates rpm and gears (high cpu, but needs to be updated often)
local VehicleSpeedUpdatePeriod = 32 -- perfect: 16 really high - 32, high - 45, medium - 85, default - 100; Updates speed (low cpu, but needs to be updated really often) 
local DashboardUpdatePeriod = 500 -- high - 500, default - 1000; Updates everything on the dashboard below the speedometer and the engine health

local cache = {
    inVehicle = false,
    totalDistance = 0,
    lastPosition = nil,
    currentVehicle = nil,
    voiceMode = 2,
    voiceModes = {},
    usingRadio = false,
    isLoggedIn = false,
    PlayerData = {}
}

local exports_cache = {
    fuel = nil,
}

for _, res in pairs({ 'LegacyFuel', 'ps-fuel', 'cdn-fuel' }) do
    if GetResourceState(res) == "started" and exports[res] and exports[res].GetFuel then
        exports_cache.fuel = exports[res]
        break
    end
end

AddEventHandler("pma-voice:radioActive", function(radioTalking)
    cache.usingRadio = radioTalking
end)

AddEventHandler('pma-voice:setTalkingMode', function(newTalkingRange)
    cache.voiceMode = newTalkingRange
end)

TriggerEvent("pma-voice:settingsCallback", function(voiceSettings)
    local voiceTable = voiceSettings.voiceModes
    for i = 1, #voiceTable do
        cache.voiceModes[i] = tostring(math.ceil((i / #voiceTable) * 100))
    end
end)

local function getPlayerData()
    return GetPlayerData()
end

local function waitForPlayerLoad()
    while not IsPlayerLoaded() do
        Wait(1000)
    end
    cache.PlayerData = getPlayerData()
    cache.isLoggedIn = true
    TriggerEvent("hud:client:LoadMap")
end

local function getLocation()
    local coords = GetEntityCoords(PlayerPedId())
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = GetStreetNameFromHashKey(streetHash)

    if crossingHash ~= 0 then
        street = street .. ' & ' .. GetStreetNameFromHashKey(crossingHash)
    end

    return {
        street = street,
        area = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    }
end

local function getFuelLevel(vehicle)
    if exports_cache.fuel then
        return exports_cache.fuel:GetFuel(vehicle)
    end
    return GetVehicleFuelLevel(vehicle)
end

local function getVehicleData(vehicle)
    local fuel = getFuelLevel(vehicle) or 0
    return {
        speed = math.ceil(GetEntitySpeed(vehicle) * 3.6),
        rpm = GetVehicleCurrentRpm(vehicle),
        gear = GetVehicleCurrentGear(vehicle),
        engine = GetIsVehicleEngineRunning(vehicle),
        fuel = math.ceil(fuel)
    }
end

local function updatePlayerInfo()
    local ped = PlayerPedId()

    cache.PlayerData = getPlayerData()

    local meta = cache.PlayerData.metadata or {}

    SendNUIMessage({
        type = 'updateHUD',
        health = GetEntityHealth(ped) - 100,
        armor = GetPedArmour(ped),
        hunger = meta.hunger or 100,
        thirst = meta.thirst or 100,
        stress = meta.stress or 0,
        stamina = 100
    })

    SendNUIMessage({
        type = 'updatePlayerInfo',
        data = {
            job = string.format('%s · %s', cache.PlayerData.job.label, cache.PlayerData.job.grade.name),
            cash = cache.PlayerData.money.cash,
            bank = cache.PlayerData.money.bank,
            id = GetPlayerServerId(PlayerId()),
            voice = {
                level = cache.voiceModes[cache.voiceMode],
                talking = NetworkIsPlayerTalking(PlayerId())
            }
        }
    })
end

local function updateVehicleStatus(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local isDriving = vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped

    if isDriving ~= cache.inVehicle then
        cache.inVehicle = isDriving
        DisplayRadar(isDriving)
        SendNUIMessage({ type = 'toggleVehicleHUD', show = isDriving })
    end

    SendNUIMessage({ type = 'setVehicleStatus', inVehicle = cache.inVehicle })
    return vehicle, isDriving
end

local function updateOdometer(vehicle, speed)
    if cache.currentVehicle ~= vehicle then
        cache.currentVehicle = vehicle
        cache.totalDistance = math.random(50000, 150000)
        cache.lastPosition = nil
    end

    if cache.lastPosition and speed > 1 then
        local currentPos = GetEntityCoords(vehicle)
        local distance = #(currentPos - cache.lastPosition)
        if distance > 0.5 and distance < 50 then
            cache.totalDistance = cache.totalDistance + (distance * 0.000621371)
        end
    end

    cache.lastPosition = GetEntityCoords(vehicle)
end

local function getGearDisplay(gear, engine)
    if gear == 0 then
        return "R"
    elseif gear == -1 then
        return "P"
    elseif not engine then
        return "N"
    else
        return gear
    end
end

local function updateVehicleHUD(vehicle)
    local vdata = getVehicleData(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local coords = GetEntityCoords(PlayerPedId())
    local location = getLocation()
    local _, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)

    updateOdometer(vehicle, vdata.speed)

    local speedMph = math.ceil(vdata.speed * 0.621371)
    local rpmValue = vdata.rpm * 10000
    local gearDisplay = getGearDisplay(vdata.gear, vdata.engine)
    local indicatorLights = GetVehicleIndicatorLights(vehicle)
    SendNUIMessage({
        type = 'updateVehicle',
        speed = speedMph,
        fuel = vdata.fuel,
        engineHealth = math.ceil((engineHealth / 1000) * 100),
        odometer = math.ceil(cache.totalDistance),
        vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
        rpm = rpmValue,
        gear = gearDisplay,
        seatbeltOn = hasSeatbelt(),
        leftTurnSignal = indicatorLights & 1 > 0,
        rightTurnSignal = indicatorLights & 2 > 0,
        hazardLights = indicatorLights == 3,
        headlights = lightsOn and highBeamsOn,
        shortLights = lightsOn,
        highLights = highBeamsOn,
        vehicleBroken = engineHealth < 300 or not vdata.engine,
        handbrake = GetVehicleHandbrake(vehicle),
        engineWarning = engineHealth < 500 or not vdata.engine
    })

    SendNUIMessage({
        type = 'updateLocation',
        street = location.street or 'Ubicación desconocida',
        zone = location.area or 'Zona desconocida',
        coordinates = string.format('%.0f', math.sqrt(coords.x ^ 2 + coords.y ^ 2)),
        distance = string.format('%.0f°', GetEntityHeading(PlayerPedId()))
    })
end

local function updateGPS(vehicle)
    local coords = GetEntityCoords(PlayerPedId())
    local location = getLocation()

    SendNUIMessage({
        type = 'updateLocation',
        street = location.street or 'Ubicación desconocida',
        zone = location.area or 'Zona desconocida',
        coordinates = string.format('%.0f', math.sqrt(coords.x ^ 2 + coords.y ^ 2)),
        distance = string.format('%.0f°', GetEntityHeading(PlayerPedId()))
    })
end

local function updateSpeedometer(vehicle)
    local vdata = getVehicleData(vehicle)
    local rpmValue = vdata.rpm * 10000
    local gearDisplay = getGearDisplay(vdata.gear, vdata.engine)
    SendNUIMessage({
        type = 'updateVehicle',
        fuel = vdata.fuel,
        odometer = math.ceil(cache.totalDistance),
        vehicleName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
        rpm = rpmValue,
        gear = gearDisplay,
    })
end

local function updateSpeed(vehicle)
    local speed = GetEntitySpeed(vehicle)
    updateOdometer(vehicle, speed)

    local speedMph = math.round(speed * 2.236936) --use math.round for very slightly more accurate and smoother changing
        SendNUIMessage({
        type = 'updateVehicle',
        speed = speedMph,
    })
end

local function updateDashboard(vehicle)
    local vdata = getVehicleData(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local _, lightsOn, highBeamsOn = GetVehicleLightsState(vehicle)
    local indicatorLights = GetVehicleIndicatorLights(vehicle)
    SendNUIMessage({
        type = 'updateVehicle',
        engineHealth = math.ceil((engineHealth / 1000) * 100),
        seatbeltOn = hasSeatbelt(),
        leftTurnSignal = indicatorLights & 1 > 0,
        rightTurnSignal = indicatorLights & 2 > 0,
        hazardLights = indicatorLights == 3,
        headlights = lightsOn and highBeamsOn,
        shortLights = lightsOn,
        highLights = highBeamsOn,
        vehicleBroken = engineHealth < 300 or not vdata.engine,
        handbrake = GetVehicleHandbrake(vehicle),
        engineWarning = engineHealth < 500 or not vdata.engine
    })
end

CreateThread(waitForPlayerLoad)

CreateThread(function()
    while true do
        if cache.isLoggedIn then
            local ped = PlayerPedId()
            updatePlayerInfo()
        end
        Wait(PlayerInfoUpdatePeriod)
    end
end)

CreateThread(function()
    while true do
        if cache.isLoggedIn then
            local ped = PlayerPedId()
            local vehicle, isDriving = updateVehicleStatus(ped)

            if cache.inVehicle then
                updateGPS(vehicle)
            end
        end
        Wait(GPSUpdatePeriod)
    end
end)

CreateThread(function()
    while true do
        if cache.isLoggedIn then
            local ped = PlayerPedId()
            local vehicle, isDriving = updateVehicleStatus(ped)

            if cache.inVehicle then
                updateSpeedometer(vehicle)
            end
        end
        Wait(VehicleSpeedometerUpdatePeriod)
    end
end)

CreateThread(function()
    while true do
        if cache.isLoggedIn then
            local ped = PlayerPedId()
            local vehicle, isDriving = updateVehicleStatus(ped)

            if cache.inVehicle then
                updateSpeed(vehicle)
            end
        end
        Wait(VehicleSpeedUpdatePeriod)
    end
end)

CreateThread(function()
    while true do
        if cache.isLoggedIn then
            local ped = PlayerPedId()
            local vehicle, isDriving = updateVehicleStatus(ped)

            if cache.inVehicle then
                updateDashboard(vehicle)
            end
        end
        Wait(DashboardUpdatePeriod)
    end
end)
