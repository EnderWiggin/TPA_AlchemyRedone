---@omw-context player

local async = require('openmw.async')
local storage = require('openmw.storage')

---@class MainSettings
---@field b_ShowFullEffectInfo boolean

local main = storage.playerSection('TPA_AlchemyRedone/MainSettings')



local config = {
    ---@type MainSettings
    main = main:asTable(),
}

main:subscribe(async:callback(function() config.main = main:asTable() end))

return config
