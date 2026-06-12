local ox_inventory = exports.ox_inventory
local oxmysql = exports.oxmysql
local stashes = {}

local function LoadJobStashes()
    stashes = {}

    oxmysql:execute('SELECT name, stash_location, stash_capacity, stash_slots FROM jobs', {}, function(result)
        if not result then
            return
        end

        for _, job in ipairs(result) do
            if job.stash_location and job.stash_location ~= '' then
                local coords = json.decode(job.stash_location)

                if coords then
                    local stashId = 'stash_' .. job.name
                    local capacity = tonumber(job.stash_capacity) or 30000
                    local slots = tonumber(job.stash_slots) or 50

                    ox_inventory:RegisterStash(stashId, job.name .. ' Stash', slots, capacity, false, job.name)
                    table.insert(stashes, {
                        id = stashId,
                        job = job.name,
                        coords = vector3(coords.x, coords.y, coords.z),
                        capacity = capacity,
                        slots = slots
                    })
                end
            end
        end

        TriggerClientEvent('stash:updateStashes', -1, stashes)
    end)
end

RegisterNetEvent('d-jobcreator:loadjobstashes', function()
    LoadJobStashes()
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(1000, LoadJobStashes)
    end
end)

RegisterNetEvent('esx:playerLoaded', function()
    LoadJobStashes()
end)

RegisterCommand(Config.reloadStashes, function(source)
    if source == 0 then
        LoadJobStashes()
        print('Stashes reloaded from database.')
    end
end, true)
