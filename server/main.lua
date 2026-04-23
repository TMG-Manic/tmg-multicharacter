local TMGCore = exports['tmg-core']:GetCoreObject()
local hasDonePreloading = {}
local Countries = json.decode(LoadResourceFile(GetCurrentResourceName(), '/countries.json'))



local function GiveStarterItems(source)
    local src = source
    local Player = TMGCore.Functions.GetPlayer(src)
    for _, v in pairs(TMGCore.Shared.StarterItems) do
        local info = {}
        if v.item == 'id_card' then
            info.citizenid = Player.PlayerData.citizenid
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.gender = Player.PlayerData.charinfo.gender
            info.nationality = Player.PlayerData.charinfo.nationality
        elseif v.item == 'driver_license' then
            info.firstname = Player.PlayerData.charinfo.firstname
            info.lastname = Player.PlayerData.charinfo.lastname
            info.birthdate = Player.PlayerData.charinfo.birthdate
            info.type = 'Class C Driver License'
        end
        exports['tmg-inventory']:AddItem(src, v.item, v.amount, false, info, 'tmg-multicharacter:GiveStarterItems')
    end
end

local function loadHouseData(src)
    local HouseGarages = {}
    local Houses = {}
    
    local result = exports['tmgnosql']:FetchAll('houselocations', {})
    
    if result and #result > 0 then
        for _, v in pairs(result) do
            local isOwned = (v.owned == true or v.owned == 1)
            
            local garage = v.garage or {}
            
            Houses[v.name] = {
                ["coords"] = v.coords,           
                ["owned"] = isOwned,
                ["price"] = v.price or 0,
                ["locked"] = true,               
                ["adress"] = v.label or "Unknown Address",
                ["tier"] = v.tier or 1,
                ["garage"] = garage,
                ["decorations"] = v.decorations or {}, 
            }
            
            HouseGarages[v.name] = {
                ["label"] = v.label or "Private Garage",
                ["takeVehicle"] = garage,
            }
        end

        TriggerClientEvent('tmg-garages:client:houseGarageConfig', src, HouseGarages)
        TriggerClientEvent('tmg-houses:client:setHouseConfig', src, Houses)
        
        print(string.format("^5[TMG]^7 Housing Sector: Streamed %d properties to Source %d", #result, src))
    else
        print("^3[TMG]^7 Housing Sector: Warning - No housing locations found in 'houselocations'.")
    end
end



TMGCore.Commands.Add('logout', Lang:t('commands.logout_description'), {}, false, function(source)
    local src = source
    TMGCore.Player.Logout(src)
    TriggerClientEvent('tmg-multicharacter:client:chooseChar', src)
end, 'admin')

TMGCore.Commands.Add('closeNUI', Lang:t('commands.closeNUI_description'), {}, false, function(source)
    local src = source
    TriggerClientEvent('tmg-multicharacter:client:closeNUI', src)
end)



AddEventHandler('TMGCore:Server:PlayerLoaded', function(Player)
    Wait(1000) 
    hasDonePreloading[Player.PlayerData.source] = true
end)

AddEventHandler('TMGCore:Server:OnPlayerUnload', function(src)
    hasDonePreloading[src] = false
end)

RegisterNetEvent('tmg-multicharacter:server:disconnect', function()
    local src = source
    DropPlayer(src, Lang:t('commands.droppedplayer'))
end)



RegisterNetEvent('tmg-multicharacter:server:loadUserData', function(cData)
    local src = source
    
    if not cData or not cData.citizenid then 
        print("^1[TMG]^7 Error: Received nil character data for Source: " .. src)
        return 
    end

    if TMGCore.Player.Login(src, cData.citizenid) then
        repeat
            Wait(10)
        until hasDonePreloading[src]

        print('^2[tmg-core]^7 ' .. GetPlayerName(src) .. ' (Citizen ID: ' .. cData.citizenid .. ') has successfully loaded!')
        
        TMGCore.Commands.Refresh(src)
        loadHouseData(src)

        if Config.SkipSelection then
            local coords = cData.position or Config.DefaultSpawn
            TriggerClientEvent('tmg-multicharacter:client:spawnLastLocation', src, coords, cData)
        else
            if GetResourceState('tmg-apartments') == 'started' then
                TriggerClientEvent('apartments:client:setupSpawnUI', src, cData)
            else
                TriggerClientEvent('tmg-spawn:client:setupSpawns', src, cData, false, nil)
                TriggerClientEvent('tmg-spawn:client:openUI', src, true)
            end
        end
        local discord = TMGCore.Functions.GetIdentifier(src, 'discord') or "none"
        local ip = TMGCore.Functions.GetIdentifier(src, 'ip') or "undefined"
        local license = TMGCore.Functions.GetIdentifier(src, 'license') or "undefined"

        TriggerEvent('tmg-log:server:CreateLog', 'joinleave', 'Loaded', 'green', 
            '**' .. GetPlayerName(src) .. '** (<@' .. (discord:gsub('discord:', '') or 'unknown') .. '> | ' .. ip .. ' | ' .. license .. ' | ' .. cData.citizenid .. ' | ' .. src .. ') loaded..')
    end
end)

RegisterNetEvent('tmg-multicharacter:server:createCharacter', function(data)
    local src = source
    local newData = {}
    newData.cid = data.cid
    newData.charinfo = data
    if TMGCore.Player.Login(src, false, newData) then
        repeat
            Wait(10)
        until hasDonePreloading[src]
        if GetResourceState('tmg-apartments') == 'started' and Apartments.Starting then
            local randbucket = (GetPlayerPed(src) .. math.random(1, 999))
            SetPlayerRoutingBucket(src, randbucket)
            print('^2[tmg-core]^7 ' .. GetPlayerName(src) .. ' has successfully loaded!')
            TMGCore.Commands.Refresh(src)
            loadHouseData(src)
            TriggerClientEvent('tmg-multicharacter:client:closeNUI', src)
            TriggerClientEvent('apartments:client:setupSpawnUI', src, newData)
            GiveStarterItems(src)
        else
            print('^2[tmg-core]^7 ' .. GetPlayerName(src) .. ' has successfully loaded!')
            TMGCore.Commands.Refresh(src)
            loadHouseData(src)
            TriggerClientEvent('tmg-multicharacter:client:closeNUIdefault', src)
            GiveStarterItems(src)
            TriggerEvent('apartments:client:SetHomeBlip', nil)
        end
    end
end)

RegisterNetEvent('tmg-multicharacter:server:deleteCharacter', function(citizenid)
    local src = source
    if not Config.EnableDeleteButton then return end
    TMGCore.Player.DeleteCharacter(src, citizenid)
    TriggerClientEvent('TMGCore:Notify', src, Lang:t('notifications.char_deleted'), 'success')
end)



TMGCore.Functions.CreateCallback('tmg-multicharacter:server:getServerLogs', function(source, cb)
    local logs = exports['tmgnosql']:FetchAll('server_logs', 
        {}, 
        { ["sort"] = { ["timestamp"] = -1 }, ["limit"] = 50 } 
    )

    if logs and #logs > 0 then
        cb(logs)
    else
        cb({})
    end

    print(string.format("^5[TMG]^7 Audit Sector: Logs streamed to Source %d", source))
end)

TMGCore.Functions.CreateCallback('tmg-multicharacter:server:GetUserCharacters', function(source, cb)
    local license = TMGCore.Functions.GetIdentifier(source, 'license')
    local result = exports['tmgnosql']:FetchAll('players', { license = license })
    cb(result or {})
end)


TMGCore.Functions.CreateCallback('tmg-multicharacter:server:GetNumberOfCharacters', function(source, cb)
    local src = source
    local license = TMGCore.Functions.GetIdentifier(src, 'license')
    local numOfChars = 0
    if Config and Config.PlayersNumberOfCharacters and type(Config.PlayersNumberOfCharacters) == "table" and next(Config.PlayersNumberOfCharacters) then
        local found = false
        for _, v in pairs(Config.PlayersNumberOfCharacters) do
            if v.license == license then
                numOfChars = v.numberOfChars
                found = true
                break
            end
        end
        if not found then
            numOfChars = Config.DefaultNumberOfCharacters or 5
        end
    else
        numOfChars = (Config and Config.DefaultNumberOfCharacters) or 5
    end
    cb(numOfChars, Countries)
    print("^5[TMG]^7 Character slots validated for Source: " .. src .. " (Slots: " .. numOfChars .. ")")
end)

TMGCore.Functions.CreateCallback('tmg-multicharacter:server:setupCharacters', function(source, cb)
    local license = TMGCore.Functions.GetIdentifier(source, 'license')
    local result = exports['tmgnosql']:FetchAll('players', { license = license })
    
    cb(result or {})
end)

TMGCore.Functions.CreateCallback('tmg-multicharacter:server:getSkin', function(source, cb, cid)
    local result = exports['tmgnosql']:FetchOne('playerskins', { 
        ["citizenid"] = cid, 
        ["active"] = 1 
    })
    
    if result then
        cb(result.model, result.skin)
        
        print(string.format("^5[TMG]^7 Identity: Visual profile resolved for CID %s", cid))
    else
        cb(nil)
    end
end)

TMGCore.Commands.Add('deletechar', Lang:t('commands.deletechar_description'), { { name = Lang:t('commands.citizenid'), help = Lang:t('commands.citizenid_help') } }, false, function(source, args)
    if args and args[1] then
        TMGCore.Player.ForceDeleteCharacter(tostring(args[1]))
        TriggerClientEvent('TMGCore:Notify', source, Lang:t('notifications.deleted_other_char', { citizenid = tostring(args[1]) }))
    else
        TriggerClientEvent('TMGCore:Notify', source, Lang:t('notifications.forgot_citizenid'), 'error')
    end
end, 'god')
