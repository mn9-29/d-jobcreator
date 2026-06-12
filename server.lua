lib.locale()

-- ─────────────────────────────────────────────────────────────
-- Security helpers
-- ─────────────────────────────────────────────────────────────
local cooldowns = {}

-- Returns true if the player is authorised AND not spamming actions.
local function authorise(src)
    if not Framework.HasPermission(src) then
        Framework.Notify(src, 'error', locale('no_permissions'))
        print(('[d-jobcreator] ^3Unauthorised action blocked^7 from player %s'):format(src))
        return false
    end
    local now = GetGameTimer()
    local last = cooldowns[src]
    if last and (now - last) < (Config.ActionCooldown * 1000) then
        return false
    end
    cooldowns[src] = now
    return true
end

AddEventHandler('playerDropped', function()
    cooldowns[source] = nil
end)

-- Validation primitives
local L = Config.Limits

local function validStr(v, maxLen)
    return type(v) == 'string' and #v > 0 and #v <= maxLen
end

-- Job/grade identifiers: lowercase letters, digits and underscores only.
local function validIdentifier(v)
    return validStr(v, L.jobNameMax) and v:match('^[%w_]+$') ~= nil
end

local function validInt(v, min, max)
    v = tonumber(v)
    if not v then return false end
    v = math.floor(v)
    return v >= min and v <= max, v
end

local function validCoords(v)
    return type(v) == 'table'
        and tonumber(v.x) and tonumber(v.y) and tonumber(v.z)
end

local function validVehicles(v)
    if type(v) ~= 'table' then return false end
    if #v > L.vehiclesMax then return false end
    for _, model in ipairs(v) do
        if type(model) ~= 'string' or #model == 0 or #model > 32 then
            return false
        end
    end
    return true
end

-- ─────────────────────────────────────────────────────────────
-- Jobs
-- ─────────────────────────────────────────────────────────────
local function getJobsList()
    local jobs = {}
    local result = MySQL.query.await('SELECT name, label FROM jobs')
    if result then
        for _, job in ipairs(result) do
            jobs[#jobs + 1] = { name = job.name or 'Undefined', label = job.label }
        end
    end
    return jobs
end

-- Open request: validated server-side, only then the UI is opened.
RegisterNetEvent('d-jobcreator:openRequest', function()
    local src = source
    if not authorise(src) then return end
    TriggerClientEvent('d-jobcreator:openUI', src, getJobsList())
end)

-- Jobs list refresh from the UI (authorised).
RegisterNetEvent('d-jobcreator:requestJobsList', function()
    local src = source
    if not Framework.HasPermission(src) then return end
    TriggerClientEvent('d-jobcreator:receiveJobsList', src, getJobsList())
end)

RegisterNetEvent('d-jobcreator:getJobGrades', function(jobName)
    local src = source
    if not authorise(src) then return end
    if not validIdentifier(jobName) then return end

    local grades = MySQL.query.await(
        'SELECT job_name, grade, name, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade ASC',
        { jobName }
    ) or {}
    TriggerClientEvent('d-jobcreator:receiveJobGrades', src, grades)
end)

RegisterNetEvent('d-jobcreator:updateJobGrades', function(updates)
    local src = source
    if not authorise(src) then return end
    if type(updates) ~= 'table' or #updates == 0 then return end

    local failCount = 0
    for _, u in ipairs(updates) do
        local okSalary, salary = validInt(u.salary, 0, L.salaryMax)
        local okGrade, grade = validInt(u.grade, 0, L.gradeMax)
        if validIdentifier(u.job_name) and validIdentifier(u.name)
            and validStr(u.label, L.labelMax) and okSalary and okGrade then
            local affected = MySQL.update.await(
                'UPDATE job_grades SET label = ?, salary = ?, name = ? WHERE job_name = ? AND grade = ?',
                { u.label, salary, u.name, u.job_name, grade }
            )
            if not affected or affected < 1 then failCount = failCount + 1 end
        else
            failCount = failCount + 1
        end
    end

    Framework.SyncJobs()
    if failCount > 0 then
        Framework.Notify(src, 'error', locale('job_grade_update_failed'))
    else
        Framework.Notify(src, 'success', locale('job_grades_updated'))
    end
end)

RegisterNetEvent('d-jobcreator:addJob', function(data)
    local src = source
    if not authorise(src) then return end
    if type(data) ~= 'table' then return end

    local jobName = data.job_name
    local label = data.label
    local okWl, whitelisted = validInt(data.whitelisted, 0, 1)

    if not validIdentifier(jobName) or not validStr(label, L.labelMax) or not okWl then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end

    if Config.MaxJobs and Config.MaxJobs > 0 then
        local count = MySQL.scalar.await('SELECT COUNT(*) FROM jobs')
        if count and count >= Config.MaxJobs then
            return Framework.Notify(src, 'error', locale('max_jobs_reached'))
        end
    end

    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM jobs WHERE name = ? OR label = ?', { jobName, label }
    )
    if exists and exists > 0 then
        return Framework.Notify(src, 'error', locale('job_exists'))
    end

    local insertId = MySQL.insert.await(
        'INSERT INTO jobs (name, label, whitelisted) VALUES (?, ?, ?)',
        { jobName, label, whitelisted }
    )

    if insertId then
        -- Every new job needs a base grade 0 to be valid on all frameworks.
        MySQL.insert.await(
            'INSERT IGNORE INTO job_grades (job_name, grade, name, label, salary) VALUES (?, 0, ?, ?, 0)',
            { jobName, 'recruit', 'Recruit' }
        )
        Framework.SyncJobs()
        Framework.Notify(src, 'success', locale('job_added'))
        TriggerClientEvent('d-jobcreator:receiveJobsList', src, getJobsList())
    else
        Framework.Notify(src, 'error', locale('add_job_failed'))
    end
end)

RegisterNetEvent('d-jobcreator:addJobGrade', function(data)
    local src = source
    if not authorise(src) then return end
    if type(data) ~= 'table' then return end

    local jobName = data.job_name
    local name = data.name
    local label = data.label
    local okGrade, grade = validInt(data.grade, 0, L.gradeMax)
    local okSalary, salary = validInt(data.salary, 0, L.salaryMax)

    if not validIdentifier(jobName) or not validIdentifier(name)
        or not validStr(label, L.labelMax) or not okGrade or not okSalary then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end

    local nameCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM job_grades WHERE job_name = ? AND name = ?', { jobName, name }
    )
    if nameCount and nameCount > 0 then
        return Framework.Notify(src, 'error', locale('job_grade_name_exists'))
    end

    local gradeCount = MySQL.scalar.await(
        'SELECT COUNT(*) FROM job_grades WHERE job_name = ? AND grade = ?', { jobName, grade }
    )
    if gradeCount and gradeCount > 0 then
        return Framework.Notify(src, 'error', locale('job_grade_exists'))
    end

    local insertId = MySQL.insert.await(
        'INSERT INTO job_grades (job_name, name, grade, label, salary) VALUES (?, ?, ?, ?, ?)',
        { jobName, name, grade, label, salary }
    )

    if insertId then
        Framework.SyncJobs()
        Framework.Notify(src, 'success', locale('job_grade_added'))
        TriggerClientEvent('d-jobcreator:receiveJobGrades', src,
            MySQL.query.await('SELECT job_name, grade, name, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade ASC', { jobName }) or {})
    else
        Framework.Notify(src, 'error', locale('job_grade_added_failed'))
    end
end)

RegisterNetEvent('d-jobcreator:deleteJobGrade', function(jobName, grade)
    local src = source
    if not authorise(src) then return end
    local okGrade, g = validInt(grade, 0, L.gradeMax)
    if not validIdentifier(jobName) or not okGrade then return end

    local affected = MySQL.update.await(
        'DELETE FROM job_grades WHERE job_name = ? AND grade = ?', { jobName, g }
    )
    if affected and affected > 0 then
        Framework.SyncJobs()
        TriggerClientEvent('d-jobcreator:receiveJobGrades', src,
            MySQL.query.await('SELECT job_name, grade, name, label, salary FROM job_grades WHERE job_name = ? ORDER BY grade ASC', { jobName }) or {})
    else
        Framework.Notify(src, 'error', locale('job_grade_deleted_failed'))
    end
end)

RegisterNetEvent('d-jobcreator:deleteJob', function(jobName)
    local src = source
    if not authorise(src) then return end
    if not validIdentifier(jobName) then
        return Framework.Notify(src, 'error', locale('no_job_found'))
    end

    MySQL.update.await('DELETE FROM job_grades WHERE job_name = ?', { jobName })

    local affectedJobs = MySQL.update.await('DELETE FROM jobs WHERE name = ?', { jobName })
    if not affectedJobs or affectedJobs < 1 then
        return Framework.Notify(src, 'error', locale('job_deleted_failed'))
    end

    MySQL.update.await('DELETE FROM d_garages WHERE job = ?', { jobName })

    Framework.RemoveJob(jobName)
    Framework.SyncJobs()
    Framework.Notify(src, 'success', locale('job_deleted'))
    TriggerClientEvent('d-jobcreator:receiveJobsList', src, getJobsList())
end)

-- ─────────────────────────────────────────────────────────────
-- Garages (management = admin only)
-- ─────────────────────────────────────────────────────────────
RegisterNetEvent('garage:getGaragesForJob', function(job)
    local src = source
    if not authorise(src) then return end
    if not validIdentifier(job) then return end

    local garages = MySQL.query.await('SELECT * FROM d_garages WHERE job = ?', { job }) or {}
    TriggerClientEvent('d-jobcreator:receiveGarages', src, garages)
end)

RegisterNetEvent('garage:addNewGarage', function(data)
    local src = source
    if not authorise(src) then return end
    if type(data) ~= 'table' then
        return Framework.Notify(src, 'error', locale('no_data_received'))
    end

    if not validCoords(data.location) or not validCoords(data.spawn_location) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not validIdentifier(data.job) or not validStr(data.name or '', L.labelMax) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not Config.GarageTypes[data.type] then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not validVehicles(data.vehicles) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end

    local blip = (data.blip == true or data.blip == 1) and 1 or 0

    local insertId = MySQL.insert.await(
        'INSERT INTO d_garages (job, name, location, spawn_location, vehicles, type, blip) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { data.job, data.name, json.encode(data.location), json.encode(data.spawn_location), json.encode(data.vehicles), data.type, blip }
    )

    if insertId then
        Framework.Notify(src, 'success', locale('garage_added'))
        TriggerClientEvent('d-jobcreator:receiveGarages', src,
            MySQL.query.await('SELECT * FROM d_garages WHERE job = ?', { data.job }) or {})
        reloadGaragesFor(-1)
    else
        Framework.Notify(src, 'error', locale('garage_add_error'))
    end
end)

RegisterNetEvent('d-jobcreator:updateGarage', function(data)
    local src = source
    if not authorise(src) then return end
    if type(data) ~= 'table' then return end

    local okId, id = validInt(data.id, 1, 2147483647)
    if not okId then
        return Framework.Notify(src, 'error', locale('garage_update_error'))
    end
    if not validCoords(data.location) or not validCoords(data.spawn_location) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not validIdentifier(data.job) or not validStr(data.name or '', L.labelMax) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not Config.GarageTypes[data.type] then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end
    if not validVehicles(data.vehicles) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end

    local blip = (data.blip == true or data.blip == 1) and 1 or 0

    local affected = MySQL.update.await(
        'UPDATE d_garages SET name = ?, location = ?, spawn_location = ?, vehicles = ?, type = ?, blip = ? WHERE id = ?',
        { data.name, json.encode(data.location), json.encode(data.spawn_location), json.encode(data.vehicles), data.type, blip, id }
    )

    if affected and affected > 0 then
        Framework.Notify(src, 'success', locale('garage_updated'))
        TriggerClientEvent('d-jobcreator:receiveGarages', src,
            MySQL.query.await('SELECT * FROM d_garages WHERE job = ?', { data.job }) or {})
        reloadGaragesFor(-1)
    else
        Framework.Notify(src, 'error', locale('garage_update_error'))
    end
end)

RegisterNetEvent('d-jobcreator:deleteGarage', function(id, job)
    local src = source
    if not authorise(src) then return end
    local okId, gid = validInt(id, 1, 2147483647)
    if not okId or not validIdentifier(job) then return end

    local affected = MySQL.update.await('DELETE FROM d_garages WHERE id = ?', { gid })
    if affected and affected > 0 then
        Framework.Notify(src, 'success', locale('garage_deleted'))
        TriggerClientEvent('d-jobcreator:receiveGarages', src,
            MySQL.query.await('SELECT * FROM d_garages WHERE job = ?', { job }) or {})
        reloadGaragesFor(-1)
    else
        Framework.Notify(src, 'error', locale('garage_deleted_error'))
    end
end)

-- ─────────────────────────────────────────────────────────────
-- Garages (gameplay = any player, server-validated)
-- ─────────────────────────────────────────────────────────────
function reloadGaragesFor(target)
    local results = MySQL.query.await('SELECT id, job, name, location FROM d_garages')
    if results and #results > 0 then
        TriggerClientEvent('d-jobcreator:loadGarages', target, results)
    end
end

RegisterNetEvent('reloadgarages', function()
    reloadGaragesFor(source)
end)

RegisterCommand(Config.reloadGarages, function(src)
    if src ~= 0 then return end -- console only
    reloadGaragesFor(-1)
    print('[d-jobcreator] Garages reloaded from database.')
end, true)

-- Vehicle list: the job is derived SERVER-SIDE and the garage must belong to it.
RegisterNetEvent('d-jobcreator:getVehiclesForJob', function(garageId)
    local src = source
    local okId, gid = validInt(garageId, 1, 2147483647)
    if not okId then return end

    local playerJob = Framework.GetPlayerJob(src)
    if not playerJob then return end

    local garage = MySQL.single.await(
        'SELECT vehicles, spawn_location, job FROM d_garages WHERE id = ?', { gid }
    )
    if not garage or garage.job ~= playerJob then
        return Framework.Notify(src, 'error', locale('no_job_found'))
    end

    TriggerClientEvent('d-jobcreator:loadVehicles', src, {
        vehicles = garage.vehicles,
        spawn_location = garage.spawn_location,
    })
end)

-- ─────────────────────────────────────────────────────────────
-- Stashes
-- ─────────────────────────────────────────────────────────────
RegisterNetEvent('d-jobcreator:getStashLocation', function(job)
    local src = source
    if not authorise(src) then return end
    if not validIdentifier(job) then return end

    local result = MySQL.single.await(
        'SELECT stash_location, stash_capacity, stash_slots FROM jobs WHERE name = ?', { job }
    )
    if result then
        local stashLocation = result.stash_location and json.decode(result.stash_location) or nil
        TriggerClientEvent('d-jobcreator:receiveStashLocation', src,
            stashLocation, tonumber(result.stash_capacity), tonumber(result.stash_slots))
    else
        TriggerClientEvent('d-jobcreator:receiveStashLocation', src, nil)
    end
end)

RegisterNetEvent('d-jobcreator:updateStashLocation', function(data)
    local src = source
    if not authorise(src) then return end
    if type(data) ~= 'table' or not validIdentifier(data.jobName) then return end
    if not validCoords(data.stashLocation) then
        return Framework.Notify(src, 'error', locale('locations_invalid'))
    end

    local okCap, capacity = validInt(data.stashCapacity, 0, L.stashWeight)
    local okSlots, slots = validInt(data.stashSlots, 0, L.stashSlots)
    if not okCap or not okSlots then return end

    MySQL.update.await(
        'UPDATE jobs SET stash_location = ?, stash_capacity = ?, stash_slots = ? WHERE name = ?',
        { json.encode(data.stashLocation), capacity, slots, data.jobName }
    )
    TriggerEvent('d-jobcreator:loadjobstashes')
end)

-- ─────────────────────────────────────────────────────────────
-- Boot: sync DB jobs into the active framework on resource start.
-- ─────────────────────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if not Framework.IsReady() then return end
    SetTimeout(2000, function() Framework.SyncJobs() end)
end)
