---@omw-context global

local I = require('openmw.interfaces')

local MODNAME = 'TPA_AlchemyRedone'

I.Settings.registerGroup {
    key = MODNAME .. '/ReworkSettings',
    page = MODNAME,
    l10n = MODNAME,
    name = 'ReworkSettingsName',
    description = 'ReworkSettingsDesc',
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
    },
}
