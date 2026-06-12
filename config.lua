Config = {}

-- ┌─────────────────────────────────────────────────────────────┐
-- │ FRAMEWORK                                                    │
-- └─────────────────────────────────────────────────────────────┘
-- "auto" detects the running framework automatically.
-- Force a specific one with: "esx", "qbcore", or "qbx".
Config.Framework = "auto"

-- ┌─────────────────────────────────────────────────────────────┐
-- │ COMMANDS                                                     │
-- └─────────────────────────────────────────────────────────────┘
Config.openJobCreator = "jobcreator"   -- opens the job creator UI
Config.reloadGarages  = "reloadgarages" -- console only
Config.reloadStashes  = "reloadstashes" -- console only

-- ┌─────────────────────────────────────────────────────────────┐
-- │ SECURITY                                                     │
-- └─────────────────────────────────────────────────────────────┘
-- Groups / ace permissions allowed to OPEN and USE the job creator.
-- Checked SERVER-SIDE on every privileged action.
Config.AllowedGroups = {
    "admin",
    "superadmin",
}

-- Minimum seconds between privileged actions from the same player (anti-spam).
Config.ActionCooldown = 0.5

-- Print extra debug info to the server/client console.
Config.Debug = false

-- Maximum number of jobs admins can create through the UI.
-- 0 = unlimited. Set a value to protect against abuse / performance issues.
Config.MaxJobs = 0

-- ┌─────────────────────────────────────────────────────────────┐
-- │ NOTIFICATIONS                                                │
-- └─────────────────────────────────────────────────────────────┘
-- "djonza" (built-in NUI), "ox_lib", "framework" (esx/qbcore/qbx native), "custom"
Config.NotificationSystem = "djonza"

-- ┌─────────────────────────────────────────────────────────────┐
-- │ GARAGES / STASHES                                           │
-- └─────────────────────────────────────────────────────────────┘
Config.npcModel = 'a_m_m_eastsa_02' -- ped model used for garage NPCs

-- Allowed garage vehicle categories.
Config.GarageTypes = { car = true, helicopter = true, boat = true }

-- Validation limits (server-side input sanitisation).
Config.Limits = {
    jobNameMax  = 50,
    labelMax    = 100,
    gradeMax    = 50,    -- highest grade number allowed
    salaryMax   = 100000000,
    vehiclesMax = 50,    -- max vehicles per garage
    stashSlots  = 200,
    stashWeight = 4000000,
}
