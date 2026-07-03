---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')

local C = require('scripts.TPABOBAP.UIToolkit.constants')

---@class ConfigDataPlayer
---@field main MainSettings

---@class MainSettings
---@field b_Enabled boolean?
---@field b_ShowFullEffectInfo boolean?
---@field b_AllowOwnedContainerIngredients boolean?
---@field b_AllowCorpseIngredients boolean?

---@class InterfaceSettings
---@field s_intReMode InterfaceReimaginedMode

---@type ConfigDataPlayer
local config = {
    ---@type MainSettings
    main = {},
    ---@type InterfaceSettings
    ui = {
        s_intReMode = C.InterfaceReimaginedMode.Auto,
    },
}

---@param section openmw.storage.StorageSection
local function subscribe(section, name)
    section:subscribe(async:callback(function() config[name] = section:asTable() end))
    config[name] = section:asTable()
end

local main = storage.playerSection('TPA_AlchemyRedone/MainSettings')
subscribe(main, 'main')

local ui = storage.playerSection('TPA_AlchemyRedone/InterfaceSettings')
subscribe(ui, 'ui')

return config
