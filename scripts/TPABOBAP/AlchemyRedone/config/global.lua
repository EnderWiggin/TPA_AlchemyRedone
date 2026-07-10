---@omw-context global

local async = require('openmw.async')
local storage = require('openmw.storage')
local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')


---@class ConfigDataGlobal
---@field rework ReworkSettings

---@class ReworkSettings
---@field b_Enabled boolean?
---@field b_UseBaseAlchemyForKnowledge boolean?
---@field n_PotionKnowledgeThreshold number?
---@field n_IngredientKnowledgeThreshold number?
---@field n_IngredientMaxTaste number?

---@type ConfigDataGlobal
local config = {
    rework = {},
    PROGRESS = 1,
    THRESHOLD = 5,
}

---@param section openmw.storage.StorageSection
local function subscribe(section, name)
    section:subscribe(async:callback(function() config[name] = section:asTable() end))
    config[name] = section:asTable()
end


local rework = storage.globalSection(CFG.SECTION.GLOBAL.Rework)
subscribe(rework, 'rework')

return config
