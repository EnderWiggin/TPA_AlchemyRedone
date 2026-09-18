---@omw-context none

local MOD = 'TPA_AlchemyRedone'

local function section(name)
    return 'Settings/' .. MOD .. '/' .. name
end

return {
    MOD = MOD,
    SECTION = {
        PLAYER = {
            WINDOW = section('AlchemyWindow')
        },
        MENU = {
            Main = section('Main'),
            Nearby = section('Nearby'),
            Interface = section('Interface'),
            Controller = section('Controller'),
        },
        GLOBAL = {
            Rework = section('Rework'),
        },
    },
    BINDING = {
        Activate = 'c_Activate',
        Brew = 'c_Brew',
        ClearText = 'c_ClearText',
        ToggleType = 'c_ToggleType',
        ToggleTable = 'c_ToggleTable',
        CountMore = 'c_CountMore',
        CountLess = 'c_CountLess',
        SelectNext = 'c_SelectNext',
        SelectPrev = 'c_SelectPrev',
    },
}
