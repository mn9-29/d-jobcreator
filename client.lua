lib.locale()

local nuiVisible = false

local function openJobManager()
    if not nuiVisible then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'open' })
        nuiVisible = true
    end
end

local function closeJobManager()
    if nuiVisible then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
        nuiVisible = false
    end
end

-- ─────────────────────────────────────────────────────────────
-- Opening the creator (permission is verified SERVER-SIDE)
-- ─────────────────────────────────────────────────────────────
RegisterCommand(Config.openJobCreator, function()
    TriggerServerEvent('d-jobcreator:openRequest')
end, false)

RegisterNetEvent('d-jobcreator:openUI', function(jobs)
    openJobManager()
    SendNUIMessage({ type = 'jobsList', jobs = jobs })
end)

RegisterNUICallback('close', function(_, cb)
    closeJobManager()
    cb('ok')
end)

-- ─────────────────────────────────────────────────────────────
-- Notifications
-- ─────────────────────────────────────────────────────────────
RegisterNetEvent('d-jobcreator:notify', function(msgType, message, duration)
    Framework.Notify(msgType, message, duration)
end)

-- Kept for backwards compatibility with the built-in NUI notifications.
RegisterNetEvent('showNotification', function(msgType, message, duration)
    Framework.Notify(msgType, message, duration)
end)

-- ─────────────────────────────────────────────────────────────
-- Jobs / grades NUI callbacks
-- ─────────────────────────────────────────────────────────────
RegisterNetEvent('d-jobcreator:receiveJobsList', function(jobs)
    SendNUIMessage({ type = 'jobsList', jobs = jobs })
end)

RegisterNUICallback('getJobsList', function(_, cb)
    TriggerServerEvent('d-jobcreator:requestJobsList')
    cb('ok')
end)

RegisterNUICallback('addJob', function(data, cb)
    TriggerServerEvent('d-jobcreator:addJob', data)
    cb({ status = 'ok' })
end)

RegisterNUICallback('deleteJob', function(data, cb)
    TriggerServerEvent('d-jobcreator:deleteJob', data.job_name)
    cb('success')
end)

RegisterNUICallback('getJobGrades', function(data, cb)
    TriggerServerEvent('d-jobcreator:getJobGrades', data.jobName)
    cb('ok')
end)

RegisterNetEvent('d-jobcreator:receiveJobGrades', function(grades)
    SendNUIMessage({ type = 'jobGrades', grades = grades })
end)

RegisterNUICallback('addJobGrade', function(data, cb)
    TriggerServerEvent('d-jobcreator:addJobGrade', data)
    cb({ status = 'ok' })
end)

RegisterNUICallback('updateJobGrades', function(data, cb)
    if data and data.data then
        TriggerServerEvent('d-jobcreator:updateJobGrades', data.data)
    end
    cb('ok')
end)

RegisterNUICallback('deleteJobGrade', function(data, cb)
    TriggerServerEvent('d-jobcreator:deleteJobGrade', data.job_name, data.grade)
    cb('success')
end)

-- ─────────────────────────────────────────────────────────────
-- Garages NUI callbacks
-- ─────────────────────────────────────────────────────────────
RegisterNetEvent('d-jobcreator:receiveGarages', function(garages)
    SendNUIMessage({ type = 'loadGarages', garages = garages })
end)

RegisterNUICallback('getGaragesForJob', function(data, cb)
    TriggerServerEvent('garage:getGaragesForJob', data.jobName)
    cb('ok')
end)

RegisterNUICallback('addNewGarage', function(data, cb)
    TriggerServerEvent('garage:addNewGarage', data)
    cb({ success = true })
end)

RegisterNUICallback('updateGarage', function(data, cb)
    if not data.id then
        return cb({ success = false, message = 'Invalid garage id!' })
    end
    TriggerServerEvent('d-jobcreator:updateGarage', data)
    cb({ success = true })
end)

RegisterNUICallback('deleteGarage', function(data, cb)
    TriggerServerEvent('d-jobcreator:deleteGarage', data.id, data.job)
    cb('success')
end)

-- ─────────────────────────────────────────────────────────────
-- Stash NUI callbacks
-- ─────────────────────────────────────────────────────────────
RegisterNUICallback('getStashLocation', function(data, cb)
    TriggerServerEvent('d-jobcreator:getStashLocation', data.jobName)
    cb({ success = true })
end)

RegisterNetEvent('d-jobcreator:receiveStashLocation', function(stashLocation, stashCapacity, stashSlots)
    if stashLocation then
        SendNUIMessage({
            action = 'setStashLocation',
            location = stashLocation,
            capacity = stashCapacity,
            slots = stashSlots,
        })
    end
end)

RegisterNUICallback('updateStash', function(data, cb)
    TriggerServerEvent('d-jobcreator:updateStashLocation', data)
    cb({ success = true })
end)

-- ─────────────────────────────────────────────────────────────
-- Garage world entities (NPCs) + ox_target zones
-- ─────────────────────────────────────────────────────────────
local function decodeCoordinates(coordString)
    if type(coordString) == 'table' then
        return vector3(coordString.x + 0.0, coordString.y + 0.0, coordString.z + 0.0)
    end
    local coords = {}
    for v in string.gmatch(coordString, '([-?%d.]+)') do
        coords[#coords + 1] = tonumber(v)
    end
    return vector3(coords[1], coords[2], coords[3])
end

local function createNPC(location)
    RequestModel(Config.npcModel)
    local started = GetGameTimer()
    while not HasModelLoaded(Config.npcModel) do
        Wait(0)
        if GetGameTimer() - started > 10000 then return nil end
    end
    local npc = CreatePed(4, Config.npcModel, location.x, location.y, location.z - 1.0, 0.0, false, true)
    SetEntityInvincible(npc, true)
    FreezeEntityPosition(npc, true)
    SetBlockingOfNonTemporaryEvents(npc, true)
    SetModelAsNoLongerNeeded(Config.npcModel)
    return npc
end

local garages = {}

local function clearGarages()
    for _, garage in pairs(garages) do
        if garage.npc and DoesEntityExist(garage.npc) then
            DeleteEntity(garage.npc)
        end
    end
    garages = {}
end

RegisterNetEvent('d-jobcreator:loadGarages', function(data)
    if type(data) ~= 'table' or #data == 0 then return end

    clearGarages()

    for _, garage in ipairs(data) do
        if garage.location and garage.job then
            local location = decodeCoordinates(garage.location)

            local npcExists = false
            for _, existing in pairs(garages) do
                if existing.coords and #(existing.coords - location) < 0.5 then
                    npcExists = true
                    break
                end
            end

            if not npcExists then
                local npc = createNPC(location)
                garages[#garages + 1] = {
                    id = garage.id,
                    name = garage.name,
                    npc = npc,
                    coords = location,
                    job = garage.job,
                }
            end
        end
    end
end)

RegisterNetEvent('d-jobcreator:loadVehicles', function(data)
    if type(data) ~= 'table' or not data.vehicles then
        return Framework.Notify('error', locale('no_vehicles'))
    end

    local decoded = type(data.vehicles) == 'string' and json.decode(data.vehicles) or data.vehicles
    if type(decoded) ~= 'table' or #decoded == 0 then
        return Framework.Notify('error', locale('no_vehicles'))
    end

    local options = {}
    for _, vehicle in ipairs(decoded) do
        options[#options + 1] = {
            title = vehicle,
            description = vehicle,
            icon = 'car',
            event = 'd-jobcreator:spawnVehicle',
            args = { vehicleModel = vehicle, spawnpoint = data.spawn_location },
        }
    end

    lib.registerContext({ id = 'vehicle_menu', title = 'Vehicles', options = options })
    lib.showContext('vehicle_menu')
end)

RegisterNetEvent('d-jobcreator:spawnVehicle', function(data)
    local vehicleModel = data.vehicleModel
    if not vehicleModel or vehicleModel == '' then
        return Framework.Notify('error', locale('model_doesnt_exist'))
    end

    local spawnpoint = decodeCoordinates(data.spawnpoint)
    if IsPedInAnyVehicle(PlayerPedId(), false) then return end

    if not Framework.IsSpawnClear(spawnpoint, 3.0) then
        return Framework.Notify('error', locale('spawnpoint_not_clear'))
    end

    local playerPed = PlayerPedId()
    local heading = GetEntityHeading(playerPed)

    Framework.SpawnVehicle(vehicleModel, spawnpoint, heading, function(vehicle)
        if vehicle and DoesEntityExist(vehicle) then
            TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
        else
            Framework.Notify('error', locale('model_doesnt_exist'))
        end
    end)
end)

-- ─────────────────────────────────────────────────────────────
-- Proximity ox_target zone for the player's own garages
-- ─────────────────────────────────────────────────────────────
CreateThread(function()
    local playerJob = nil
    local isNear = false
    local currentGarage = nil
    local currentZone = nil

    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        playerJob = Framework.GetJobName()

        local nearestGarage, nearestDistance = nil, math.huge
        for _, garage in pairs(garages) do
            if garage.job == playerJob and garage.coords then
                local distance = #(playerCoords - garage.coords)
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestGarage = garage
                end
            end
        end

        if nearestGarage and nearestDistance < 5.0 then
            if not isNear or currentGarage ~= nearestGarage then
                isNear = true
                currentGarage = nearestGarage
                if currentZone then exports.ox_target:removeZone(currentZone) end
                local garageId = nearestGarage.id
                currentZone = exports.ox_target:addBoxZone({
                    coords = nearestGarage.coords,
                    size = vector3(2.0, 2.0, 2.0),
                    rotation = 0.0,
                    debug = false,
                    options = {
                        {
                            name = 'open_garage_zone',
                            icon = 'fa-solid fa-box-open',
                            label = locale('open_garage'),
                            onSelect = function()
                                TriggerServerEvent('d-jobcreator:getVehiclesForJob', garageId)
                            end,
                        },
                        {
                            name = 'return_garage_zone',
                            icon = 'fa-solid fa-arrow-rotate-left',
                            label = locale('return_vehicle'),
                            onSelect = function()
                                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                                if DoesEntityExist(vehicle) then
                                    DeleteEntity(vehicle)
                                end
                            end,
                        },
                    },
                })
            end
            sleep = 0
        elseif isNear then
            if currentZone then exports.ox_target:removeZone(currentZone) end
            isNear = false
            currentGarage = nil
            currentZone = nil
        end

        Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Refresh garages on load / job change
-- ─────────────────────────────────────────────────────────────
local function requestGarages()
    if Framework.GetJobName() then
        TriggerServerEvent('reloadgarages')
    end
end

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        requestGarages()
    end
end)

Framework.OnJobChange(function()
    clearGarages()
    requestGarages()
end)
