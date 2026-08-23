---@omw-context player

local cfgPlayer = require 'scripts.TPABOBAP.AlchemyRedone.config.player'
local cfgGlobal = require 'scripts.TPABOBAP.AlchemyRedone.config.global'

local I = require 'openmw.interfaces'
local A = require 'scripts.TPABOBAP.AlchemyRedone.alchemy'

---@class AlchemyRedone.Integration.UIToolkit
local M = {}

function M.register()
    if not I.UTKTooltips then return end
    I.UTKTooltips.addPreCreateTooltipHandler(M.modifyUTKTooltip)
end

local function findByName(items, name)
    for index, item in ipairs(items or {}) do
        if item.name == name then
            return item, index
        end
    end
end

---@param recipe UTKTooltips.Recipe
---@param tooltip UTKTooltips.Tooltip
function M.modifyUTKTooltip(recipe, tooltip)
    if not cfgGlobal.rework.b_Enabled or not cfgPlayer.main.b_Enabled then return end

    local type = recipe.type or tooltip.type

    local isPotion = type == I.UTKTooltips.TYPE.Potion
    if not isPotion and type ~= I.UTKTooltips.TYPE.Ingredient then
        return
    end
    local observer = tooltip.observer -- or player
    local recordId = tooltip.key or tooltip.object.recordId
    ---@type boolean[]
    local knowledge = isPotion
        and A.getKnownEffectFlagsForPotion(recordId, observer)
        or A.getKnownEffectFlagsForIngredient(recordId, observer)

    for i = 1, #knowledge do
        knowledge[i] = not knowledge[i]
    end

    local item = findByName(recipe.items, I.UTKTooltips.CONTENT.MagicEffects)
    if not item then return end
    item.unknown = knowledge
end

return M
