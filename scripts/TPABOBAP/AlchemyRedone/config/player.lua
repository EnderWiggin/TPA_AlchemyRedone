---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')
local omwConstants = require('scripts.omw.mwui.constants')

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
---@field n_TextSizeTitle integer?
---@field n_TextSizeContent integer?
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
    text = {
        normal = omwConstants.textNormalSize,
        title = omwConstants.textNormalSize,
        content = omwConstants.textNormalSize,
    },
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

local COMPACT_TEXT_CAP = 16
local function updateTextConfig()
    --three size tiers: TEXT_SIZE (menu base), TITLE_TEXT (headings), CONTENT_TEXT (contents, tables, tooltips)
    --compact caps the base and lowers the tiers; all render code reads tiers, never the mode
    local compact = config.ui.b_CompactMode
    local sz = config.ui.n_TextSize or 0

    if sz <= 0 then sz = omwConstants.textNormalSize + sz end
    if compact then sz = math.min(sz, COMPACT_TEXT_CAP) end

    local szt = config.ui.n_TextSizeTitle or 0
    if not compact then
        szt = sz
    elseif szt <= 0 then
        szt = math.max(13, sz + szt)
    end

    local szc = config.ui.n_TextSizeContent or 0
    if not compact then
        szc = sz
    elseif szc <= 0 then
        szc = math.max(13, sz + szc)
    end

    config.text.normal = sz
    config.text.title = szt
    config.text.content = szc
end
storage.playerSection(CFG.SECTION.MENU.Interface):subscribe(async:callback(updateTextConfig))

local controls = storage.playerSection(CFG.SECTION.MENU.Controller)
subscribe(controls, 'controls')

return config
