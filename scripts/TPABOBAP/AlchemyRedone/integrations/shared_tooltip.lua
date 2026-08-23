---@omw-context player

local ui = require 'openmw.ui'

local cfgPlayer = require 'scripts.TPABOBAP.AlchemyRedone.config.player'
local cfgGlobal = require 'scripts.TPABOBAP.AlchemyRedone.config.global'

local I = require 'openmw.interfaces'

---@class AlchemyRedone.Integration.SharedTooltip
local M = {}

function M.register()
    if not I.SharedTooltip then return end
    I.SharedTooltip.registerModifier { id = 'TPA_AlchemyRedone', priority = 0, func = M.modifySharedTooltip }
end

---@param tip SharedTooltip.TipContext
function M.modifySharedTooltip(tip)
    if not cfgGlobal.rework.b_Enabled or not cfgPlayer.main.b_Enabled then return end

    ---@type boolean[]
    local knowledge
    ---@type openmw.ui.Layout
    local group
    ---@type table[]
    local effects
    ---@type boolean|'potion'
    local isAlchemy = true

    if tip.info.ingredientEffects then
        effects = tip.info.ingredientEffects
        group = tip.flex.content['ingredientEffects']
        knowledge = I.TPA_AlchemyRedone.getKnownEffectFlagsForIngredient(tip.record.id)
    end

    if tip.info.potionEffects then
        effects = tip.info.potionEffects
        group = tip.flex.content['potionEffects']
        knowledge = I.TPA_AlchemyRedone.getKnownEffectFlagsForPotion(tip.record.id)
        isAlchemy = 'potion'
    end

    if not group then return end
    for i = 1, #effects do
        local effect = effects[i]
        if effect then
            effect.known = knowledge[i]
        end
    end

    group.content = ui.content({})
    tip.printEffects(group, effects, isAlchemy)
end

return M
