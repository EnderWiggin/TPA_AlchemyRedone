---@omw-context global

local I = require('openmw.interfaces')

local MODNAME = 'TPA_AlchemyRedone'

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
        {
            key = 'b_ReplacePotionKnowledge',
            renderer = 'checkbox',
            name = 'SettingReplacePotionKnowledge',
            description = 'SettingReplacePotionKnowledgeDesc',
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
