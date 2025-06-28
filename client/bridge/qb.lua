local availableCores = { 'qb-core', 'qbx_core' }
local hasFramework

for i = 1, #availableCores, 1 do
    if not hasResource(availableCores[i]) then
        hasFramework = availableCores[i]
    end
end

if not hasFramework then return end

lib.print.info('QBCore Bridge Ready')

local QBCore = exports['qb-core']:GetCoreObject()

local PlayerData, isLoggedIn = {}, false

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() isLoggedIn = false end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job) PlayerData.job = job end)
RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang) PlayerData.gang = gang end)
RegisterNetEvent('QBCore:Player:SetPlayerData', function(data) PlayerData = data end)

_G.GetPlayerData = QBCore.Functions.GetPlayerData
_G.IsPlayerLoaded = function() return LocalPlayer.state.isLoggedIn end
