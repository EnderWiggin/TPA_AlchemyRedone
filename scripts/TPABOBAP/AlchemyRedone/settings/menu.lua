---@omw-context menu

local input = require('openmw.input')
local I = require('openmw.interfaces')
local C = require('scripts.TPABOBAP.UIToolkit.constants')
local H = require('scripts.TPABOBAP.UIToolkit.helpers')

local MODNAME = 'TPA_AlchemyRedone'
local l10n = require('openmw.core').l10n(MODNAME)

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

I.Settings.registerGroup {
    key = MODNAME .. '/ControllerSettings',
    page = MODNAME,
    l10n = MODNAME,
    name = 'ControllerSettingsName',
    description = 'ControllerSettingsDesc',
    order = 4,
    permanentStorage = true,
    settings = {
        {
            key = 'n_Activate',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_Activate',
            description = 'SettingController_ActivateDesc',
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
