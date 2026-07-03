---@omw-context global

local async = require('openmw.async')
local storage = require('openmw.storage')


---@class ConfigDataGlobal
---@field rework ReworkSettings

---@class ReworkSettings
---@field b_Enabled boolean?

---@type ConfigDataGlobal
local config = {
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


local rework = storage.globalSection('TPA_AlchemyRedone/ReworkSettings')
subscribe(rework, 'rework')

return config
