---@omw-context global

local I = require('openmw.interfaces')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')
local C = require('scripts.TPABOBAP.UIToolkit.constants')

local MODNAME = 'TPA_AlchemyRedone'
local l10n = require('openmw.core').l10n(MODNAME)

local KnowledgeThreshold = {
    default = 5,
    min = 1,
    max = 20,
}

I.Settings.registerGroup {
    key = MODNAME .. '/ReworkSettings',
    page = MODNAME,
    l10n = MODNAME,
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
    },
}
