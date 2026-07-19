---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')

local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
local C = require('scripts.TPABOBAP.UIToolkit.constants')

---@class ConfigDataPlayer
---@field main MainSettings
---@field nearby NearbySettings
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

---@class NearbySettings
---@field b_AllowNearbySources boolean?
---@field b_AllowOwnedApparatus boolean?
---@field b_AllowFactionOwned boolean?
---@field b_AllowOwnedContainerIngredients boolean?
---@field b_AllowCorpseIngredients boolean?

---@class InterfaceSettings
---@field s_intReMode InterfaceReimaginedMode
---@field b_CompactMode boolean?
---@field n_TextSize integer?
---@field s_NumberSeparators string?
---@field b_ShowUseHint boolean?

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
    nearby = {},
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

local main = storage.playerSection(CFG.SECTION.MENU.Main)
subscribe(main, 'main')

local nearby = storage.playerSection(CFG.SECTION.MENU.Nearby)
subscribe(nearby, 'nearby')

local ui = storage.playerSection(CFG.SECTION.MENU.Interface)
subscribe(ui, 'ui')


local controls = storage.playerSection(CFG.SECTION.MENU.Controller)
subscribe(controls, 'controls')

return config
