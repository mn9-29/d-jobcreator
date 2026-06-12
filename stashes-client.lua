local stashLocations = {}
local stashObjects = {}

local function SpawnStashObjects()
    for _, obj in ipairs(stashObjects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    stashObjects = {}

    local stashModel = `prop_ld_int_safe_01`

    for _, stash in ipairs(stashLocations) do
        RequestModel(stashModel)
        local started = GetGameTimer()
        while not HasModelLoaded(stashModel) do
            Wait(0)
            if GetGameTimer() - started > 10000 then break end
        end

        local obj = CreateObject(stashModel, stash.coords.x, stash.coords.y, stash.coords.z - 1.0, false, false, false)
        if DoesEntityExist(obj) then
            SetEntityHeading(obj, 0.0)
            FreezeEntityPosition(obj, true)
            stashObjects[#stashObjects + 1] = obj

            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open stash',
                    icon = 'fa-solid fa-box-open',
                    onSelect = function()
                        if Framework.GetJobName() == stash.job then
                            exports.ox_inventory:openInventory('stash', stash.id)
                        end
                    end,
                },
            })
        end
    end

    SetModelAsNoLongerNeeded(stashModel)
end

RegisterNetEvent('stash:updateStashes', function(data)
    stashLocations = data or {}
    SpawnStashObjects()
end)
