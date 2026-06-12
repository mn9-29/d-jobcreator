local stashes = {}

local function LoadJobStashes()
    stashes = {}

    local result = MySQL.query.await('SELECT name, stash_location, stash_capacity, stash_slots FROM jobs')
    if not result then return end

    for _, job in ipairs(result) do
        if job.stash_location and job.stash_location ~= '' then
            local coords = json.decode(job.stash_location)
            if coords and coords.x then
                local stashId = 'stash_' .. job.name
                local capacity = tonumber(job.stash_capacity) or 30000
                local slots = tonumber(job.stash_slots) or 50

                -- The 6th argument (owner/group) restricts access to the job,
                -- enforced server-side by ox_inventory.
                exports.ox_inventory:RegisterStash(stashId, job.name .. ' Stash', slots, capacity, false, job.name)

                stashes[#stashes + 1] = {
                    id = stashId,
                    job = job.name,
                    coords = { x = coords.x, y = coords.y, z = coords.z },
                    capacity = capacity,
                    slots = slots,
                }
            end
        end
    end

    TriggerClientEvent('stash:updateStashes', -1, stashes)
end

RegisterNetEvent('d-jobcreator:loadjobstashes', function()
    -- Server-only event (not exposed to clients via the net layer for writes).
    if source ~= 0 and GetInvokingResource() ~= GetCurrentResourceName() then
        if not Framework.HasPermission(source) then return end
    end
    LoadJobStashes()
end)

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        SetTimeout(1500, LoadJobStashes)
    end
end)

RegisterCommand(Config.reloadStashes, function(src)
    if src ~= 0 then return end -- console only
    LoadJobStashes()
    print('[d-jobcreator] Stashes reloaded from database.')
end, true)
