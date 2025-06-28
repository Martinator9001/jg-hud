local seatbeltIsOn = false
local seatbeltDamageReduction = 0.8 -- %80 damage reduction when seatbelt is on
local seatbeltEjectSpeed = 60       -- Speed threshold for ejection without seatbelt
local currentVehicle
local seatbeltThread = nil

local function stopSeatbeltThread()
    if seatbeltThread then
        seatbeltThread = nil
    end
end

local function startCarThread()
    if seatbeltThread then return end -- Evitar múltiples threads

    seatbeltThread = CreateThread(function()
        while currentVehicle and IsPedInAnyVehicle(PlayerPedId()) do
            local ped = PlayerPedId()
            local vehicle = currentVehicle

            if not vehicle or not DoesEntityExist(vehicle) then
                break
            end

            local speed = GetEntitySpeed(vehicle) * 3.6

            -- Solo aplicar efectos de eyección si NO tiene cinturón
            if speed > seatbeltEjectSpeed and not seatbeltIsOn then
                if HasEntityCollidedWithAnything(vehicle) then
                    local coords = GetEntityCoords(ped)
                    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0)
                    SetEntityVelocity(ped, 0.0, 0.0, 5.0)
                    SetPedToRagdoll(ped, 5000, 5000, 0, 0, 0, 0)
                end
            end

            if seatbeltIsOn then
                DisableControlAction(0, 75, true)
                SetPedConfigFlag(ped, 32, false)
            else
                SetPedConfigFlag(ped, 32, true)
            end

            Wait(seatbeltIsOn and 0 or 100)
        end

        seatbeltThread = nil
    end)
end


lib.addKeybind({
    name = GetGameTimer() .. '-seatbelt',
    description = 'Put your seatbelt on/off',
    defaultKey = 'B',
    onPressed = function()
        print('Presionado', currentVehicle)
        if not currentVehicle or IsPauseMenuActive() then return end

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped) then return end

        local class = GetVehicleClass(GetVehiclePedIsUsing(ped))
        if class == 8 or class == 13 or class == 14 then return end -- Excluir motos, bicicletas, etc.

        seatbeltIsOn = not seatbeltIsOn

        TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5.0, seatbeltIsOn and "carbuckle" or "carunbuckle",
            0.25)

        exports['qb-core']:Notify(
            ('Te has %s el cinturon'):format(seatbeltIsOn and 'puesto' or 'quitado')
        )
    end
})

exports('hasSeatbelt', function()
    return seatbeltIsOn
end)


lib.onCache('vehicle', function(veh)
    local previousVehicle = currentVehicle
    currentVehicle = veh

    if not veh and previousVehicle and seatbeltIsOn then
        seatbeltIsOn = false
        stopSeatbeltThread()
        TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5.0, "carunbuckle", 0.25)
        exports['qb-core']:Notify('Te has quitado el cinturon al salir del vehiculo')
    end

    if veh and not previousVehicle then
        seatbeltIsOn = false
        startCarThread()
    end

    if not veh and previousVehicle then
        stopSeatbeltThread()
    end
end)
