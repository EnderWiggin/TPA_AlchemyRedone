---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')

---@class ConfigDataPlayer
---@field main MainSettings

---@class MainSettings
---@field b_Enabled boolean?
---@field b_ShowFullEffectInfo boolean?
---@field b_AllowOwnedContainerIngredients boolean?
---@field b_AllowCorpseIngredients boolean?

---@type ConfigDataPlayer
local config = {
    ---@type MainSettings
    main = {},
}

---@param section openmw.storage.StorageSection
local function subscribe(section, name)
    section:subscribe(async:callback(function() config[name] = section:asTable() end))
    config[name] = section:asTable()
end

local main = storage.playerSection('TPA_AlchemyRedone/MainSettings')
subscribe(main, 'main')


return config
