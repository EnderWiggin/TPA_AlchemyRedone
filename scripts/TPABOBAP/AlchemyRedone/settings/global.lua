---@omw-context global

local I = require('openmw.interfaces')
local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')
local C = require('scripts.TPABOBAP.UIToolkit.constants')

local l10n = require('openmw.core').l10n(CFG.MOD)

local KnowledgeThreshold = {
    default = 5,
    min = 1,
    max = 20,
}

local IngredientThreshold = {
    default = 25,
    min = 10,
    max = 50,
}

local IngredientMaxTaste = {
    default = 3,
    min = 0,
    max = 4,
}

I.Settings.registerGroup {
    key = CFG.SECTION.GLOBAL.Rework,
    page = CFG.MOD,
    l10n = CFG.MOD,
    name = 'ReworkSettingsName',
    description = l10n('ReworkSettingsDesc', C.TextColorParams),
    order = 2,
    permanentStorage = true,
    settings = {
        {
            key = 'b_Enabled',
            renderer = 'checkbox',
            name = 'SettingReworkEnabled',
            description = 'SettingSettingReworkEnabledDesc',
            default = false,
        },
        {
            key = 'n_PotionKnowledgeThreshold',
            renderer = 'number',
            name = 'SettingPotionKnowledgeThreshold',
            description = l10n('SettingPotionKnowledgeThresholdDesc', H.mergeTables(C.TextColorParams, KnowledgeThreshold)),
            default = KnowledgeThreshold.default,
            argument = {
                min = KnowledgeThreshold.min,
                max = KnowledgeThreshold.max,
                integer = true,
            }
        },
        {
            key = 'n_IngredientKnowledgeThreshold',
            renderer = 'number',
            name = 'SettingIngredientKnowledgeThreshold',
            description = l10n('SettingIngredientKnowledgeThresholdDesc', H.mergeTables(C.TextColorParams, IngredientThreshold)),
            default = IngredientThreshold.default,
            argument = {
                min = IngredientThreshold.min,
                max = IngredientThreshold.max,
                integer = true,
            }
        },
        {
            key = 'n_IngredientMaxTaste',
            renderer = 'number',
            name = 'SettingIngredientMaxTaste',
            description = l10n('SettingIngredientMaxTasteDesc', H.mergeTables(C.TextColorParams, IngredientMaxTaste)),
            default = IngredientMaxTaste.default,
            argument = {
                min = IngredientMaxTaste.min,
                max = IngredientMaxTaste.max,
                integer = true,
            }
        },
    },
}
