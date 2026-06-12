--[[
    Framework bridge for d-jobcreator.
    Supports: ESX (es_extended), QBCore (qb-core) and QBX (qbx_core).

    This file is loaded as a shared_script, so it runs on BOTH the server
    and the client. Functions are split by side using IsDuplicityVersion().
]]

Framework = {}

local isServer = IsDuplicityVersion()

-- ─────────────────────────────────────────────────────────────
-- Detection
-- ─────────────────────────────────────────────────────────────
local function detectFramework()
    local forced = Config.Framework
    if forced and forced ~= 'auto' then
        return forced
    end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return nil
end

Framework.Name = detectFramework()

local ESX, QBCore

local function loadCore()
    if Framework.Name == 'esx' then
        ESX = exports['es_extended']:getSharedObject()
    elseif Framework.Name == 'qbcore' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    -- qbx is accessed purely through exports.qbx_core, no shared object needed.
end

if Framework.Name then
    loadCore()
    print(('[d-jobcreator] Framework detected: %s'):format(Framework.Name))
else
    print('[d-jobcreator] ^1ERROR^7: No supported framework found (esx / qbcore / qbx).')
end

function Framework.IsReady()
    return Framework.Name ~= nil
end

-- ─────────────────────────────────────────────────────────────
-- Debug helper
-- ─────────────────────────────────────────────────────────────
function Framework.Debug(...)
    if Config.Debug then
        print('[d-jobcreator]', ...)
    end
end

-- ═════════════════════════════════════════════════════════════
-- SERVER SIDE
-- ═════════════════════════════════════════════════════════════
if isServer then

    function Framework.GetPlayer(src)
        if Framework.Name == 'esx' then
            return ESX.GetPlayerFromId(src)
        elseif Framework.Name == 'qbx' then
            return exports.qbx_core:GetPlayer(src)
        elseif Framework.Name == 'qbcore' then
            return QBCore.Functions.GetPlayer(src)
        end
    end

    -- Returns the player's current job name (server-trusted, never from client).
    function Framework.GetPlayerJob(src)
        local player = Framework.GetPlayer(src)
        if not player then return nil end
        if Framework.Name == 'esx' then
            return player.getJob and player.getJob().name or (player.job and player.job.name)
        else -- qb / qbx
            return player.PlayerData and player.PlayerData.job and player.PlayerData.job.name
        end
    end

    -- Privileged-access check. Uses ace permissions (universal) plus
    -- framework-native group checks. Returns true only if explicitly allowed.
    function Framework.HasPermission(src)
        if not src or src <= 0 then return false end

        for _, group in ipairs(Config.AllowedGroups) do
            if IsPlayerAceAllowed(src, group) or IsPlayerAceAllowed(src, 'group.' .. group) then
                return true
            end
        end

        if Framework.Name == 'esx' then
            local xPlayer = ESX.GetPlayerFromId(src)
            if xPlayer then
                local group = xPlayer.getGroup and xPlayer.getGroup() or nil
                for _, g in ipairs(Config.AllowedGroups) do
                    if group == g then return true end
                end
            end
        elseif Framework.Name == 'qbcore' then
            for _, g in ipairs(Config.AllowedGroups) do
                local ok, res = pcall(function() return QBCore.Functions.HasPermission(src, g) end)
                if ok and res then return true end
            end
        elseif Framework.Name == 'qbx' then
            for _, g in ipairs(Config.AllowedGroups) do
                local ok, res = pcall(function() return exports.qbx_core:HasPermission(src, g) end)
                if ok and res then return true end
            end
        end

        return false
    end

    function Framework.Notify(src, msgType, message)
        TriggerClientEvent('d-jobcreator:notify', src, msgType, message)
    end

    -- Build a framework-native jobs table from the DB rows.
    local function buildJobsTable(flavor)
        local jobs = {}
        local jobRows = MySQL.query.await('SELECT name, label FROM jobs') or {}
        for _, j in ipairs(jobRows) do
            local gradeRows = MySQL.query.await(
                'SELECT grade, name, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade ASC',
                { j.name }
            ) or {}

            local grades = {}
            for _, g in ipairs(gradeRows) do
                local key = flavor == 'qbcore' and tostring(g.grade) or tonumber(g.grade)
                grades[key] = {
                    name = g.label or g.name or ('grade ' .. tostring(g.grade)),
                    payment = tonumber(g.salary) or 0,
                }
            end
            -- Both qb flavors require a grade 0 to exist.
            local zeroKey = flavor == 'qbcore' and '0' or 0
            if not grades[zeroKey] then
                grades[zeroKey] = { name = 'Recruit', payment = 0 }
            end

            jobs[j.name] = {
                label = j.label or j.name,
                type = 'job',
                defaultDuty = true,
                offDutyPay = false,
                grades = grades,
            }
        end
        return jobs
    end

    -- Push all DB jobs into the active framework so they are usable live.
    function Framework.SyncJobs()
        if Framework.Name == 'esx' then
            local ok = pcall(function() ESX.RefreshJobs() end)
            if not ok then pcall(function() TriggerEvent('esx:refreshjobs') end) end
        elseif Framework.Name == 'qbx' then
            local jobs = buildJobsTable('qbx')
            local ok, err = pcall(function() exports.qbx_core:CreateJobs(jobs) end)
            if not ok then print('[d-jobcreator] ^1qbx CreateJobs failed^7:', err) end
        elseif Framework.Name == 'qbcore' then
            local jobs = buildJobsTable('qbcore')
            for name, data in pairs(jobs) do
                local ok = pcall(function() exports['qb-core']:AddJob(name, data) end)
                if not ok then
                    pcall(function() QBCore.Functions.AddJob(name, data) end)
                end
            end
        end
    end

    function Framework.RemoveJob(name)
        if Framework.Name == 'qbx' then
            pcall(function() exports.qbx_core:RemoveJob(name) end)
        elseif Framework.Name == 'qbcore' then
            local ok = pcall(function() exports['qb-core']:RemoveJob(name) end)
            if not ok then pcall(function() QBCore.Functions.RemoveJob(name) end) end
        elseif Framework.Name == 'esx' then
            pcall(function() ESX.RefreshJobs() end)
        end
    end

-- ═════════════════════════════════════════════════════════════
-- CLIENT SIDE
-- ═════════════════════════════════════════════════════════════
else

    function Framework.GetPlayerData()
        if Framework.Name == 'esx' then
            return ESX.GetPlayerData() or {}
        elseif Framework.Name == 'qbx' then
            return exports.qbx_core:GetPlayerData() or {}
        elseif Framework.Name == 'qbcore' then
            return QBCore.Functions.GetPlayerData() or {}
        end
        return {}
    end

    function Framework.GetJobName()
        local data = Framework.GetPlayerData()
        if data and data.job then return data.job.name end
        return nil
    end

    -- Native, framework-agnostic vehicle spawn.
    function Framework.SpawnVehicle(model, coords, heading, cb)
        local hash = type(model) == 'number' and model or joaat(model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            if cb then cb(nil) end
            return
        end

        RequestModel(hash)
        local started = GetGameTimer()
        while not HasModelLoaded(hash) do
            Wait(0)
            if GetGameTimer() - started > 10000 then
                if cb then cb(nil) end
                return
            end
        end

        local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, heading or 0.0, true, false)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetVehicleNeedsToBeHotwired(veh, false)
        SetVehRadioStation(veh, 'OFF')
        local netId = NetworkGetNetworkIdFromEntity(veh)
        SetNetworkIdCanMigrate(netId, true)
        SetModelAsNoLongerNeeded(hash)
        if cb then cb(veh) end
    end

    function Framework.IsSpawnClear(coords, radius)
        local veh = GetClosestVehicle(coords.x, coords.y, coords.z, radius or 3.0, 0, 71)
        return not veh or veh == 0
    end

    -- Client-side notification (built-in NUI / ox_lib / native / custom).
    function Framework.Notify(msgType, message, duration)
        local system = Config.NotificationSystem
        if system == 'djonza' then
            SendNUIMessage({
                action = 'showNotification',
                type = msgType,
                message = message,
                duration = duration or 3000,
            })
        elseif system == 'ox_lib' then
            exports['ox_lib']:notify({ description = message, type = msgType })
        elseif system == 'framework' then
            if Framework.Name == 'esx' then
                ESX.ShowNotification(message)
            elseif Framework.Name == 'qbcore' then
                QBCore.Functions.Notify(message, msgType, duration or 3000)
            elseif Framework.Name == 'qbx' then
                exports.qbx_core:Notify(message, msgType, duration or 3000)
            end
        elseif system == 'custom' then
            TriggerEvent('your_custom_notify', msgType, message, duration)
        end
    end

    -- Registers a callback fired whenever the player's job changes or they load.
    function Framework.OnJobChange(handler)
        if Framework.Name == 'esx' then
            RegisterNetEvent('esx:setJob', function(job) handler(job and job.name) end)
            RegisterNetEvent('esx:playerLoaded', function()
                handler(Framework.GetJobName())
            end)
        else -- qb / qbx share the same event names
            RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
                handler(job and job.name)
            end)
            RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
                handler(Framework.GetJobName())
            end)
        end
    end

end
