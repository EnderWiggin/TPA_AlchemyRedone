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

---@param actor openmw.LObject|openmw.GObject|nil
---@return integer
local function getKnownAlchemyEffectCount(actor, isPotion)
    if not actor or not actor.type or not actor.type.stats or not actor.type.stats.skills or not actor.type.stats.skills.alchemy then
        return 99 --consider knowing all effects when there's no actor
    end

    local alchemy = actor.type.stats.skills.alchemy(actor).base
    local threshold = core.getGMST('fWortChanceValue')
    local visibleEffectCount = math.floor(alchemy / threshold)
    if isPotion then
        visibleEffectCount = visibleEffectCount * 2
    end
    return visibleEffectCount
end

---@param ingredient string|openmw.types.IngredientRecord|nil
---@param actor openmw.LObject|openmw.GObject|nil
---@return table<integer, boolean>
Alchemy.getKnownEffectFlagsForIngredient = function(ingredient, actor)
    if type(ingredient) == "string" then
        ingredient = types.Ingredient.record(ingredient)
    end
    if not ingredient then return {} end
    local known = getKnownAlchemyEffectCount(actor, false)
    local result = {}
    for i = 1, #ingredient.effects do
        --TODO: implement custom logic for knowing effects
        result[i] = i <= known
    end
    return result
end

return Alchemy
