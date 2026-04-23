local TMGCore = exports['tmg-core']:GetCoreObject()



MultiState = {
    cam = nil,
    charPed = nil,
    loadScreenActive = false,
    cachedSkins = {}, 
    randomModels = { 'mp_m_freemode_01', 'mp_f_freemode_01' }
}



local function LoadModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
end



local function InitializePedModel(model, data)
    
    if MultiState.charPed then 
        DeleteEntity(MultiState.charPed) 
        MultiState.charPed = nil 
    end

    
    local pedModel = model or joaat(MultiState.randomModels[math.random(#MultiState.randomModels)])
    LoadModel(pedModel)
    
    local c = Config.PedCoords
    MultiState.charPed = CreatePed(2, pedModel, c.x, c.y, c.z - 0.98, c.w, false, true)
    
    
    SetPedComponentVariation(MultiState.charPed, 0, 0, 0, 2)
    FreezeEntityPosition(MultiState.charPed, false)
    SetEntityInvincible(MultiState.charPed, true)
    PlaceObjectOnGroundProperly(MultiState.charPed)
    SetBlockingOfNonTemporaryEvents(MultiState.charPed, true)

    if data then
        TriggerEvent('tmg-clothing:client:loadPlayerClothing', data, MultiState.charPed)
    end
end



local function SkyCam(bool)
    TriggerEvent('tmg-weathersync:client:DisableSync')
    if bool then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)
        
        local c = Config.CamCoords
        MultiState.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, c.w, 60.00, false, 0)
        SetCamActive(MultiState.cam, true)
        RenderScriptCams(true, false, 1, true, true)
    else
        SetTimecycleModifier('default')
        if MultiState.cam then
            SetCamActive(MultiState.cam, false)
            DestroyCam(MultiState.cam, true)
            MultiState.cam = nil
        end
        RenderScriptCams(false, false, 1, true, true)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end



local function OpenCharMenu(bool)
    TMGCore.Functions.TriggerCallback('tmg-multicharacter:server:GetNumberOfCharacters', function(result, countries)
        local translations = {}
        local phraseSource = Lang.fallback and Lang.fallback.phrases or Lang.phrases
        for k, _ in pairs(phraseSource) do
            if k:sub(1, 3) == 'ui.' then translations[k:sub(4)] = Lang:t(k) end
        end

        SetNuiFocus(bool, bool)
        SendNUIMessage({
            action = 'ui',
            customNationality = Config.customNationality,
            toggle = bool,
            nChar = result,
            enableDeleteButton = Config.EnableDeleteButton,
            translations = translations,
            countries = countries,
        })
        
        SkyCam(bool)
        if not MultiState.loadScreenActive then
            ShutdownLoadingScreenNui()
            MultiState.loadScreenActive = true
        end
        print("^5[TMG]^7 Identity nexus interface materialized.")
    end)
end



CreateThread(function()
    while true do
        Wait(0)
        if NetworkIsSessionStarted() then
            TriggerEvent('tmg-multicharacter:client:chooseChar')
            return
        end
    end
end)



RegisterNetEvent('tmg-multicharacter:client:chooseChar', function()
    SetNuiFocus(false, false)
    DoScreenFadeOut(10)
    Wait(1000)

    
    local intPos = Config.Interior
    local interior = GetInteriorAtCoords(intPos.x, intPos.y, intPos.z - 18.9)
    LoadInterior(interior)
    while not IsInteriorReady(interior) do Wait(1000) end

    FreezeEntityPosition(PlayerPedId(), true)
    SetEntityCoords(PlayerPedId(), Config.HiddenCoords.x, Config.HiddenCoords.y, Config.HiddenCoords.z)
    
    Wait(1500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    OpenCharMenu(true)
end)

RegisterNetEvent('tmg-multicharacter:client:spawnLastLocation', function(coords, cData)
    TMGCore.Functions.TriggerCallback('apartments:GetOwnedApartment', function(result)
        local ped = PlayerPedId()
        SetEntityCoords(ped, coords.x, coords.y, coords.z)
        SetEntityHeading(ped, coords.w)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true)
        
        if result then
            TriggerEvent('apartments:client:SetHomeBlip', result.type)
            local PlayerData = TMGCore.Functions.GetPlayerData()
            local insideMeta = PlayerData.metadata['inside']
            DoScreenFadeOut(500)

            if insideMeta.house then
                TriggerEvent('tmg-houses:client:LastLocationHouse', insideMeta.house)
            elseif insideMeta.apartment.apartmentType and insideMeta.apartment.apartmentId then
                TriggerEvent('tmg-apartments:client:LastLocationHouse', insideMeta.apartment.apartmentType, insideMeta.apartment.apartmentId)
            end
        end

        TriggerServerEvent('TMGCore:Server:OnPlayerLoaded')
        TriggerEvent('TMGCore:Client:OnPlayerLoaded')
        Wait(2000)
        DoScreenFadeIn(250)
        print("^5[TMG]^7 Identity materialized at last known coordinates.")
    end, cData.citizenid)
end)



RegisterNUICallback('cDataPed', function(nData, cb)
    local cData = nData.cData
    if MultiState.charPed then DeleteEntity(MultiState.charPed) end

    if cData ~= nil then
        
        if not MultiState.cachedSkins[cData.citizenid] then
            local pModel, pData = promise.new(), promise.new()
            TMGCore.Functions.TriggerCallback('tmg-multicharacter:server:getSkin', function(model, data)
                pModel:resolve(model)
                pData:resolve(data)
            end, cData.citizenid)
            
            MultiState.cachedSkins[cData.citizenid] = { 
                model = Citizen.Await(pModel), 
                data = Citizen.Await(pData) 
            }
        end

        local skin = MultiState.cachedSkins[cData.citizenid]
        local model = skin.model ~= nil and tonumber(skin.model) or false
        
        if model then InitializePedModel(model, json.decode(skin.data))
        else InitializePedModel() end
    else
        InitializePedModel()
    end
    cb('ok')
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    DoScreenFadeOut(10)
    TriggerServerEvent('tmg-multicharacter:server:loadUserData', data.cData)
    OpenCharMenu(false)
    if MultiState.charPed then DeleteEntity(MultiState.charPed) end
    cb('ok')
    print("^5[TMG]^7 Identity selected. Initializing session.")
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    DoScreenFadeOut(150)
    data.gender = (data.gender == Lang:t('ui.male')) and 0 or 1
    TriggerServerEvent('tmg-multicharacter:server:createCharacter', data)
    Wait(500)
    cb('ok')
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    TMGCore.Functions.TriggerCallback('tmg-multicharacter:server:setupCharacters', function(result)
        MultiState.cachedSkins = {} 
        SendNUIMessage({ action = 'setupCharacters', characters = result })
        cb('ok')
    end)
end)

RegisterNUICallback('removeCharacter', function(data, cb)
    TriggerServerEvent('tmg-multicharacter:server:deleteCharacter', data.citizenid)
    if MultiState.charPed then DeleteEntity(MultiState.charPed) end
    TriggerEvent('tmg-multicharacter:client:chooseChar')
    cb('ok')
end)

RegisterNUICallback('disconnectButton', function(_, cb)
    if MultiState.charPed then DeleteEntity(MultiState.charPed) end
    TriggerServerEvent('tmg-multicharacter:server:disconnect')
    cb('ok')
end)

RegisterNUICallback('closeUI', function(_, cb)
    OpenCharMenu(false)
    if MultiState.charPed then DeleteEntity(MultiState.charPed) end
    SetNuiFocus(false, false)
    SkyCam(false)
    cb('ok')
end)
