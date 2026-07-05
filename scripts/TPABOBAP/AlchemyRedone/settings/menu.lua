---@omw-context menu

local input = require('openmw.input')
local I = require('openmw.interfaces')
local C = require('scripts.TPABOBAP.UIToolkit.constants')

local MODNAME = 'TPA_AlchemyRedone'

local controllerInput = require('scripts.TPABOBAP.AlchemyRedone.settings.controllerInputRenderer')
I.Settings.registerRenderer('TPA_controllerInput', controllerInput.renderer)

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
            description = 'SettingController_ClearTextDesc',
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
            description = 'SettingController_ToggleTableDesc',
            default = input.CONTROLLER_BUTTON.RightShoulder,
        },
        {
            key = 'n_CountMore',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_CountMore',
            description = 'SettingController_CountMoreDesc',
            default = input.CONTROLLER_BUTTON.DPadRight,
        },
        {
            key = 'n_CountLess',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_CountLess',
            description = 'SettingController_CountLessDesc',
            default = input.CONTROLLER_BUTTON.DPadLeft,
        },
        {
            key = 'n_SelectNext',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_SelectNext',
            description = 'SettingController_SelectNextDesc',
            default = input.CONTROLLER_BUTTON.DPadDown,
        },
        {
            key = 'n_SelectPrev',
            renderer = 'TPA_controllerInput',
            name = 'SettingController_SelectPrev',
            description = 'SettingController_SelectPrevDesc',
            default = input.CONTROLLER_BUTTON.DPadUp,
        },
        {
            key = 'b_AllowPrecisionMode',
            renderer = 'checkbox',
            name = 'SettingAllowPrecisionMode',
            description = 'SettingAllowPrecisionModeDesc',
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
            description = 'SettingRepeatingButtonsThresholdDesc',
            default = 0.5,
            argument = {
                min = 0.2,
                max = 1,
            }
        },
        {
            key = 'n_RepeatingButtonsStep',
            renderer = 'number',
            name = 'SettingRepeatingButtonsStep',
            description = 'SettingRepeatingButtonsStepDesc',
            default = 0.125,
            argument = {
                min = 0.05,
                max = 0.5,
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
