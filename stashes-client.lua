local stashLocations = {}
local stashObjects = {}

local function GetPlayerJob()
    return ESX.GetPlayerData().job.name
end

local function SpawnStashObjects()
    for _, obj in ipairs(stashObjects) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end

    stashObjects = {}

    for _, stash in ipairs(stashLocations) do
        local stashModel = `prop_ld_int_safe_01`
        RequestModel(stashModel)
        while not HasModelLoaded(stashModel) do
            Wait(100)
        end

        local stashObject = CreateObject(stashModel, stash.coords.x, stash.coords.y, stash.coords.z - 1.0, false, false, false)

        if DoesEntityExist(stashObject) then
            SetEntityHeading(stashObject, 0.0)
            FreezeEntityPosition(stashObject, true)
            table.insert(stashObjects, stashObject)

            exports.ox_target:addLocalEntity(stashObject, {
                {
                    label = "Open stash",
                    icon = "fa-solid fa-box-open",
                    onSelect = function()
                        if GetPlayerJob() == stash.job then
                            exports.ox_inventory:openInventory('stash', stash.id)
                        end
                    end
                }
            })
        end
    end
end

RegisterNetEvent('stash:updateStashes')
AddEventHandler('stash:updateStashes', function(stashes)
    stashLocations = stashes
    SpawnStashObjects()
end)
