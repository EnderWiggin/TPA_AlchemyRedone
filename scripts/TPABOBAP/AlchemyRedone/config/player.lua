---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')

local C = require('scripts.TPABOBAP.UIToolkit.constants')

---@class ConfigDataPlayer
---@field main MainSettings
---@field ui InterfaceSettings
---@field controls ControllerSettings

---@class MainSettings
---@field b_Enabled boolean?
---@field b_ShowFullEffectInfo boolean?
---@field b_PotionArtUsesSkill boolean?
---@field b_PrefixPotionNames boolean?
---@field s_PotionNamePrefixGood string?
---@field s_PotionNamePrefixBad string?
---@field b_IngredientEffectMatchingAll boolean?
---@field b_AllowOwnedContainerIngredients boolean?
---@field b_AllowCorpseIngredients boolean?

---@class InterfaceSettings
---@field s_intReMode InterfaceReimaginedMode

---@class ControllerSettings
---@field n_Activate number?
---@field n_Brew number?
---@field n_ClearText number?
---@field n_ToggleType number?
---@field n_ToggleTable number?
---@field n_CountMore number?
---@field n_CountLess number?
---@field n_SelectNext number?
---@field n_SelectPrev number?
---@field b_AllowPrecisionMode boolean?
---@field b_RepeatingButtons boolean?
---@field n_RepeatingButtonsThreshold number?
---@field n_RepeatingButtonsStep number?

---@type ConfigDataPlayer
local config = {
    main = {},
    ui = {
        s_intReMode = C.InterfaceReimaginedMode.Auto,
    },
    controls = {},
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


local controls = storage.playerSection('TPA_AlchemyRedone/ControllerSettings')
subscribe(controls, 'controls')

return config
