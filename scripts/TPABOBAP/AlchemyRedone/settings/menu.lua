---@omw-context menu

local I = require('openmw.interfaces')
local C = require('scripts.TPABOBAP.UIToolkit.constants')

local MODNAME = 'TPA_AlchemyRedone'

I.Settings.registerPage {
    key = MODNAME,
    l10n = MODNAME,
    name = 'PageName',
    description = 'PageDesc',
}

I.Settings.registerGroup {
    key = MODNAME .. '/MainSettings',
    page = MODNAME,
    l10n = MODNAME,
    name = 'MainSettingsName',
    order = 1,
    permanentStorage = true,
    settings = {
        {
            key = 'b_Enabled',
            renderer = 'checkbox',
            name = 'SettingModEnabled',
            description = 'SettingModEnabledDesc',
            default = true,
        },
        {
            key = 'b_ShowFullEffectInfo',
            renderer = 'checkbox',
            name = 'SettingShowFullEffectInfo',
            description = 'SettingShowFullEffectInfoDesc',
            default = false,
        },
        {
            key = 'b_AllowOwnedContainerIngredients',
            renderer = 'checkbox',
            name = 'SettingAllowOwnedContainerIngredients',
            description = 'SettingAllowOwnedContainerIngredientsDesc',
            default = false,
        },
        {
            key = 'b_AllowCorpseIngredients',
            renderer = 'checkbox',
            name = 'SettingAllowCorpseIngredients',
            description = 'SettingAllowCorpseIngredientsDesc',
            default = false,
        },
    },
}


I.Settings.registerGroup {
    key = MODNAME .. '/InterfaceSettings',
    page = MODNAME,
    l10n = MODNAME,
    name = 'InterfaceSettingsName',
    order = 3,
    permanentStorage = true,
    settings = {
        {
            key = 's_intReMode',
            renderer = 'select',
            name = 'SettingIntReMode',
            default = C.InterfaceReimaginedMode.Auto,
            argument = {
                l10n = MODNAME,
                items = {
                    C.InterfaceReimaginedMode.OFF,
                    C.InterfaceReimaginedMode.Auto,
                    C.InterfaceReimaginedMode.ON,
                },
            }
        },
    },
}
