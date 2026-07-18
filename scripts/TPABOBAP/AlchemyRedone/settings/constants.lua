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
}
