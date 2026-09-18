---@omw-context menu

local input = require('openmw.input')
local I = require('openmw.interfaces')
local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
local H = require('scripts.UIToolkit.helpers')

local l10n = require('openmw.core').l10n(CFG.MOD)
local Device = require 'scripts.UIToolkit.config.defaults'.Device


local FontSize = {
    default = 0,
    min = -10,
    max = 24,
}

local FontSizeTitle = {
    default = -1,
    min = -10,
    max = 24,
}

local FontSizeContent = {
    default = -2,
    min = -10,
    max = 24,
}

I.Settings.registerPage {
    key = CFG.MOD,
    l10n = CFG.MOD,
    name = 'PageName',
    description = 'PageDesc',
}

I.Settings.registerGroup {
    key = CFG.SECTION.MENU.Main,
    page = CFG.MOD,
    l10n = CFG.MOD,
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
            key = 'b_PotionArtUsesSkill',
            renderer = 'checkbox',
            name = 'SettingPotionArtUsesSkill',
            description = l10n('SettingPotionArtUsesSkillDesc', H.TextColorParams),
            default = false,
        },
        {
            key = 'b_PrefixPotionNames',
            renderer = 'checkbox',
            name = 'SettingPrefixPotionNames',
            description = 'SettingPrefixPotionNamesDesc',
            default = true,
        },
        {
            key = 's_PotionNamePrefixGood',
            renderer = 'textLine',
            name = 'SettingPotionNamePrefixGood',
            description = 'SettingPotionNamePrefixGoodDesc',
            default = l10n('Potion_Name_Prefix_Good'),
        },
        {
            key = 's_PotionNamePrefixBad',
            renderer = 'textLine',
            name = 'SettingPotionNamePrefixBad',
            description = 'SettingPotionNamePrefixBadDesc',
            default = l10n('Potion_Name_Prefix_Bad'),
        },
        {
            key = 'b_IngredientEffectMatchingAll',
            renderer = 'checkbox',
            name = 'SettingIngredientEffectMatchingAll',
            description = 'SettingIngredientEffectMatchingAllDesc',
            default = false,
        },
    },
}

I.Settings.registerGroup {
    key = CFG.SECTION.MENU.Nearby,
    page = CFG.MOD,
    l10n = CFG.MOD,
    name = 'NearbyGroupTitle',
    order = 2,
    permanentStorage = true,
    settings = {
        {
            key = 'b_AllowNearbySources',
            renderer = 'checkbox',
            name = 'NearbySettingsName',
            description = 'NearbySettingsDesc',
            default = true,
        },
        {
            key = 'b_AllowOwnedApparatus',
            renderer = 'checkbox',
            name = 'SettingAllowOwnedApparatus',
            description = 'SettingAllowOwnedApparatusDesc',
            default = false,
        },
        {
            key = 'b_AllowFactionOwned',
            renderer = 'checkbox',
            name = 'SettingAllowFactionOwned',
            description = 'SettingAllowFactionOwnedDesc',
            default = true,
        },
        {
            key = 'b_AllowOwnedContainerIngredients',
            renderer = 'checkbox',
            name = l10n('SettingAllowOwnedContainerIngredients', H.TextColorParams),
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
    key = CFG.SECTION.MENU.Interface,
    page = CFG.MOD,
    l10n = CFG.MOD,
    name = 'InterfaceSettingsName',
    order = 3,
    permanentStorage = true,
    settings = {
        {
            key = 'b_CompactMode',
            renderer = 'checkbox',
            name = 'SettingCompactMode',
            description = l10n('SettingCompactModeDesc', H.TextColorParams),
            default = false,
        },
        {
            key = 'n_TextSize',
            renderer = 'number',
            name = 'SettingTextSize',
            description = l10n('SettingTextSizeDesc', H.mergeTables(H.TextColorParams, FontSize)),
            default = FontSize.default,
            argument = {
                integer = true,
                min = FontSize.min,
                max = FontSize.max,
            }
        },
        {
            key = 'n_TextSizeTitle',
            renderer = 'number',
            name = 'SettingTextSizeTitle',
            description = l10n('SettingTextSizeTitleDesc', H.mergeTables(H.TextColorParams, FontSizeTitle)),
            default = FontSizeTitle.default,
            argument = {
                integer = true,
                min = FontSizeTitle.min,
                max = FontSizeTitle.max,
            }
        },
        {
            key = 'n_TextSizeContent',
            renderer = 'number',
            name = 'SettingTextSizeContent',
            description = l10n('SettingTextSizeContentDesc', H.mergeTables(H.TextColorParams, FontSizeContent)),
            default = FontSizeContent.default,
            argument = {
                integer = true,
                min = FontSizeContent.min,
                max = FontSizeContent.max,
            }
        },
        {
            key = 'b_ShowUseHint',
            renderer = 'checkbox',
            name = 'SettingShowUseHint',
            description = 'SettingShowUseHintDesc',
            default = true,
        },
    },
}

I.Settings.registerGroup {
    key = CFG.SECTION.MENU.Controller,
    page = CFG.MOD,
    l10n = CFG.MOD,
    name = 'ControllerSettingsName',
    description = l10n('ControllerSettingsDesc', H.TextColorParams),
    order = 4,
    permanentStorage = true,
    settings = {
        {
            key = 'c_Activate',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_Activate',
            description = l10n('SettingController_ActivateDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.A },
                { device = Device.Keyboard,   code = input.KEY.E },
            },
        },
        {
            key = 'c_Brew',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_Brew',
            description = 'SettingController_BrewDesc',
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.X },
                { device = Device.Keyboard,   code = input.KEY.R },
            },
        },
        {
            key = 'c_ClearText',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_ClearText',
            description = l10n('SettingController_ClearTextDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.Y },
                { device = Device.Keyboard,   code = input.KEY.Q },
            },
        },
        {
            key = 'c_ToggleType',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_ToggleType',
            description = 'SettingController_ToggleTypeDesc',
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.LeftShoulder },
                { device = Device.Keyboard,   code = input.KEY.X },
            },
        },
        {
            key = 'c_ToggleTable',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_ToggleTable',
            description = l10n('SettingController_ToggleTableDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.RightShoulder },
                { device = Device.Keyboard,   code = input.KEY.F },
            },
        },
        {
            key = 'c_CountMore',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_CountMore',
            description = l10n('SettingController_CountMoreDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.DPadRight },
                { device = Device.Keyboard,   code = input.KEY.D },
            },
        },
        {
            key = 'c_CountLess',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_CountLess',
            description = l10n('SettingController_CountLessDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.DPadLeft },
                { device = Device.Keyboard,   code = input.KEY.A },
            },
        },
        {
            key = 'c_SelectNext',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_SelectNext',
            description = l10n('SettingController_SelectNextDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.DPadDown },
                { device = Device.Keyboard,   code = input.KEY.S },
            },
        },
        {
            key = 'c_SelectPrev',
            renderer = 'UIToolkit/BindCustom',
            name = 'SettingController_SelectPrev',
            description = l10n('SettingController_SelectPrevDesc', H.TextColorParams),
            default = {
                { device = Device.Controller, code = input.CONTROLLER_BUTTON.DPadUp },
                { device = Device.Keyboard,   code = input.KEY.W },
            },
        },
    },
}
