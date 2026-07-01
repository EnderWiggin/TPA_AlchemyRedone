---@omw-context menu

local I = require('openmw.interfaces')

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
            key = 'b_ShowFullEffectInfo',
            renderer = 'checkbox',
            name = 'SettingShowFullEffectInfo',
            description = 'SettingShowFullEffectInfoDesc',
            default = false,
        },
    },
}
