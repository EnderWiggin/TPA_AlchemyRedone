---@omw-context menu

local input = require('openmw.input')
local I = require('openmw.interfaces')
local CFG = require('scripts.TPABOBAP.AlchemyRedone.settings.constants')
local C = require('scripts.TPABOBAP.UIToolkit.constants')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')

local l10n = require('openmw.core').l10n(CFG.MOD)

local controllerInput = require('scripts.TPABOBAP.AlchemyRedone.settings.controllerInputRenderer')
I.Settings.registerRenderer('TPA_controllerInput', controllerInput.renderer)

local RepeatThreshold = {
    default = 0.5,
    min = 0.2,
    max = 1,
}

local RepeatStep = {
    default = 0.125,
    min = 0.05,
    max = 0.5,
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
            description = l10n('SettingPotionArtUsesSkillDesc', C.TextColorParams),
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
    key = CFG.SECTION.MENU.Interface,
    page = CFG.MOD,
    l10n = CFG.MOD,
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
                l10n = CFG.MOD,
                items = {
                    C.InterfaceReimaginedMode.OFF,
                    C.InterfaceReimaginedMode.Auto,
                    C.InterfaceReimaginedMode.ON,
                },
            }
        },
        {
            key = 'b_CompactMode',
            renderer = 'checkbox',
            name = 'SettingCompactMode',
            description = 'SettingCompactModeDesc',
            default = false,
        },
    },
}

I.Settings.registerGroup {
    key = CFG.SECTION.MENU.Controller,
    page = CFG.MOD,
    l10n = CFG.MOD,
    name = 'ControllerSettingsName',
    description = 'ControllerSettingsDesc',
    order = 4,
    permanentStorage = true,
    settings = {
        {
            key = 'n_Activate',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_Activate',
            description = l10n('SettingController_ActivateDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.A,
        },
        {
            key = 'n_Brew',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_Brew',
            description = 'SettingController_BrewDesc',
            default = input.CONTROLLER_BUTTON.X,
        },
        {
            key = 'n_ClearText',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_ClearText',
            description = l10n('SettingController_ClearTextDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.Y,
        },
        {
            key = 'n_ToggleType',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_ToggleType',
            description = 'SettingController_ToggleTypeDesc',
            default = input.CONTROLLER_BUTTON.LeftShoulder,
        },
        {
            key = 'n_ToggleTable',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_ToggleTable',
            description = l10n('SettingController_ToggleTableDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.RightShoulder,
        },
        {
            key = 'n_CountMore',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_CountMore',
            description = l10n('SettingController_CountMoreDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.DPadRight,
        },
        {
            key = 'n_CountLess',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_CountLess',
            description = l10n('SettingController_CountLessDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.DPadLeft,
        },
        {
            key = 'n_SelectNext',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_SelectNext',
            description = l10n('SettingController_SelectNextDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.DPadDown,
        },
        {
            key = 'n_SelectPrev',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_SelectPrev',
            description = l10n('SettingController_SelectPrevDesc', C.TextColorParams),
            default = input.CONTROLLER_BUTTON.DPadUp,
        },
        {
            key = 'b_AllowPrecisionMode',
            renderer = 'checkbox',
            name = 'SettingAllowPrecisionMode',
            description = l10n('SettingAllowPrecisionModeDesc', C.TextColorParams),
            default = false,
        },
        {
            key = 'b_RepeatingButtons',
            renderer = 'checkbox',
            name = 'SettingRepeatingButtons',
            description = 'SettingRepeatingButtonsDesc',
            default = true,
        },
        {
            key = 'n_RepeatingButtonsThreshold',
            renderer = 'number',
            name = 'SettingRepeatingButtonsThreshold',
            description = l10n('SettingRepeatingButtonsThresholdDesc', H.mergeTables(C.TextColorParams, RepeatThreshold)),
            default = RepeatThreshold.default,
            argument = {
                min = RepeatThreshold.min,
                max = RepeatThreshold.max,
            }
        },
        {
            key = 'n_RepeatingButtonsStep',
            renderer = 'number',
            name = 'SettingRepeatingButtonsStep',
            description = l10n('SettingRepeatingButtonsStepDesc', H.mergeTables(C.TextColorParams, RepeatStep)),
            default = RepeatStep.default,
            argument = {
                min = RepeatStep.min,
                max = RepeatStep.max,
            }
        },
    },
}

return {
    engineHandlers = {
        onKeyPress = controllerInput.handlers.onKeyPress,
        onControllerButtonPress = controllerInput.handlers.onControllerButtonPress,
    }
}
