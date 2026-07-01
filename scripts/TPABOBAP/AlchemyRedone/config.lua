---@omw-context runtime

local async = require('openmw.async')
local storage = require('openmw.storage')

---@class MainSettings
---@field b_ShowFullEffectInfo boolean
---@field b_AllowOwnedContainerIngredients boolean
---@field b_AllowCorpseIngredients boolean

local main = storage.globalSection('TPA_AlchemyRedone/MainSettings')



local config = {
    ---@type MainSettings
    main = main:asTable(),
}

main:subscribe(async:callback(function() config.main = main:asTable() end))

return config
