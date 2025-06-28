if not hasResource('es_extended') then return end

lib.print.info('ESX Bridge Ready')

local ESX = exports.es_extended:getSharedObject()
local PlayerData, isLoggedIn = {
    job = {
        label = '',
        grade = { name = '' },
        metadata = { hunger = '', thirst = '' }
    },
    money = {
        cash = 0,
        bank = 0,
    }
}, false

function getStatus(s)
    local p = promise.new()
    TriggerEvent('esx_status:getStatus', s, function(o)
        p:resolve(o.getPercent())
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('esx:playerLoaded', function(pData, isNew)
    PlayerData.job = {
        label = pData.job.label,
        grade = {
            name = pData.job.grade_label
        }
    }

    for i = 1, #pData.accounts, 1 do
        local account = pData.accounts[i].name == 'money' and 'cash' or pData.accounts[i].name
        PlayerData.money[account] = pData.accounts[i].money
    end

    PlayerData.metadata.hunger = getStatus('hunger')
    PlayerData.metadata.thirst = getStatus('thirst')
end)

RegisterNetEvent('esx_status:onTick', function(s)
    for i = 1, #s, 1 do
        if PlayerData.metadata[s[i].name] then
            PlayerData.metadata[s[i].name] = s[i].percent
        end
    end
end)

function GetPlayerData()
    local pData = PlayerData

    for i = 1, #ESX.PlayerData.accounts, 1 do
        local account = ESX.PlayerData.accounts[i].name == 'money' and 'cash' or ESX.PlayerData.accounts[i].name
        pData.money[account] = ESX.PlayerData.accounts[i].money
    end

    pData.metadata.hunger = getStatus('hunger')
    pData.metadata.thirst = getStatus('thirst')

    PlayerData.job = {
        label = ESX.PlayerData.job.label,
        grade = {
            name = ESX.PlayerData.job.grade_label
        }
    }
end

function IsPlayerLoaded()
    return ESX.IsPlayerLoaded()
end
