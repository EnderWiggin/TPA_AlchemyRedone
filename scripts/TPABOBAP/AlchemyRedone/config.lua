---@omw-context runtime

local context = require('scripts.TPABOBAP.scriptContext')
local async = require('openmw.async')

---@class ConfigData
---@field main MainSettings
---@field rework ReworkSettings

---@class MainSettings
---@field b_Enabled boolean?
---@field b_ShowFullEffectInfo boolean?
---@field b_AllowOwnedContainerIngredients boolean?
---@field b_AllowCorpseIngredients boolean?

---@class ReworkSettings
---@field b_Enabled boolean?

local ctx = context.get()

---@type ConfigData
local config = {
    ---@type MainSettings
    main = {},
    ---@type ReworkSettings
    rework = {},

    --TODO: add settings
    PROGRESS = 1,
    THRESHOLD = 5,
}

---@param section openmw.storage.StorageSection
local function subscribe(section, name)
    section:subscribe(async:callback(function() config[name] = section:asTable() end))
    config[name] = section:asTable()
end

local main
if ctx == context.Types.Player then
    ---@omw-context-begin player
    local pStorage = require('openmw.storage')
    main = pStorage.playerSection('TPA_AlchemyRedone/MainSettings')
    subscribe(main, 'main')
    ---@omw-context-end player
end

local gStorage = require('openmw.storage')

local rework = gStorage.globalSection('TPA_AlchemyRedone/ReworkSettings')
subscribe(rework, 'rework')

return config
