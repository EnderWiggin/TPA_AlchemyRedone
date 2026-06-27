---@omw-context runtime

local core = require("openmw.core")
local util = require("openmw.util")
local types = require("openmw.types")


local Alchemy = {}

---@param list? openmw.core.MagicEffectWithParams[]
---@param effect openmw.core.MagicEffectWithParams
---@return boolean
Alchemy.containsEffect = function(list, effect)
    if not list then return false end
    for i = 1, #list do
        local current = list[i]
        if current.id == effect.id
            and current.affectedAttribute == effect.affectedAttribute
            and current.affectedSkill == current.affectedSkill
        then
            return true
        end
    end
    return false
end

---@param ingredientIds string[] ordered list of ingredient ids
---@return openmw.core.MagicEffectWithParams[] ordered list of matching effect ids
Alchemy.getMatchingEffects = function(ingredientIds)
    ---@type openmw.core.MagicEffectWithParams[]
    local effects = {}

    for i = 1, #ingredientIds do
        local ingredient = types.Ingredient.record(ingredientIds[i])

        if ingredient then
            for j = i + 1, #ingredientIds do
                local ingredient2 = types.Ingredient.record(ingredientIds[j])
                if ingredient2 then
                    for k = 1, #ingredient.effects do
                        local effect = ingredient.effects[k]
                        if not Alchemy.containsEffect(effects, effect)
                            and Alchemy.containsEffect(ingredient2.effects, effect)
                        then
                            table.insert(effects, effect)
                        end
                    end
                end
            end
        end
    end

    return effects
end



return Alchemy
