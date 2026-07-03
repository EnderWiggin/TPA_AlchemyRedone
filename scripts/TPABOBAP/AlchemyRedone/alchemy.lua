---@omw-context runtime

local core = require("openmw.core")
local util = require("openmw.util")
local types = require("openmw.types")
local I = require("openmw.interfaces")

local config = require("scripts.TPABOBAP.AlchemyRedone.config")

---@param id string
---@return boolean
local function isGeneratedId(id)
    return id:lower():sub(1, 12) == "generated:0x"
end

---@class AlchemyKnowledge
---@field potionKnowledge table<string, boolean|boolean[]>
---@field ingredientKnowledge table<string, boolean[]>
---@field recipeProgress table<string, number>

local Alchemy = {
    ---@type AlchemyKnowledge
    knowledge = {
        potionKnowledge = {},
        ingredientKnowledge = {},
        recipeProgress = {},
    },
}

---@enum AlchemyPotionErrors
Alchemy.PotionErrors = {
    OK = 'sPotionSuccess',                    --- Potion can be created
    FAIL = 'sNotifyMessage8',                 --- Potion was attempted, but failed - ingredients are still consumed.
    NO_MORTAR = 'sNotifyMessage45',           --- Potion can't be created - need Mortar and pestle
    NO_NAME = 'sNotifyMessage37',             --- Potion can't be created - it needs a name
    TOO_FEW_INGREDIENTS = 'sNotifyMessage6a', --- Potion can't be created - needs more ingredients
}

---@param item openmw.Object
Alchemy.onItemConsumed = function(item)
    if not config.main.b_ReplacePotionKnowledge then return end
    if types.Potion.objectIsInstance(item) then
        Alchemy.knowledge.potionKnowledge[item.recordId] = true
    end
end

--- Updates known effects of brewed potion
---@param potion string
---@param ingredients string[]
---@param actor openmw.GObject|openmw.LObject|nil
Alchemy.updateBrewedPotionKnowledge = function(potion, ingredients, actor)
    local record = Alchemy.toPotionRecord(potion)
    if record and Alchemy.knowledge.potionKnowledge[potion] ~= true then
        local effects, known = Alchemy.getMatchingEffects(ingredients, actor)
        local all = true
        local knowledge = {}
        for i = 1, #effects do
            local k = Alchemy.containsEffect(record.effects, effects[i])
            if k then
                knowledge[k] = known[i]
                if not known[i] then
                    all = false
                end
            end
        end
        Alchemy.knowledge.potionKnowledge[potion] = all or knowledge
    end
end

---@param effectId string
---@return openmw.core.MagicEffect?
Alchemy.getEffectRecord = function(effectId)
    return core.magic.effects.records[effectId] or
        (I.MagicWindow and I.MagicWindow.Spells.getCustomEffect(effectId))
end

---@param list? openmw.core.MagicEffectWithParams[]
---@param effect openmw.core.MagicEffectWithParams
---@return integer? index where effect is in the list, or nil
Alchemy.containsEffect = function(list, effect)
    if not list then return nil end
    for i = 1, #list do
        if Alchemy.sameEffect(list[i], effect) then return i end
    end
    return nil
end

Alchemy.sameEffect = function(a, b)
    return a.id == b.id
        and a.affectedAttribute == b.affectedAttribute
        and a.affectedSkill == a.affectedSkill
end

---@param recordOrId string|openmw.types.IngredientRecord|nil
---@return openmw.types.IngredientRecord?
Alchemy.toIngredientRecord = function(recordOrId)
    if type(recordOrId) == "string" then
        return types.Ingredient.record(recordOrId)
    end
    return recordOrId
end

---@param recordOrId string|openmw.types.PotionRecord|nil
---@return openmw.types.PotionRecord?
Alchemy.toPotionRecord = function(recordOrId)
    if not recordOrId then return nil end
    if type(recordOrId) == "string" then
        return types.Potion.record(recordOrId)
    end
    return recordOrId
end

---@param recordsOrIds string[]|openmw.types.IngredientRecord[]
---@return openmw.types.IngredientRecord[]
Alchemy.toIngredientRecords = function(recordsOrIds)
    local result = {}
    for i = 1, #recordsOrIds do
        local record = Alchemy.toIngredientRecord(recordsOrIds[i])
        if record then table.insert(result, record) end
    end
    return result
end

---@param recordsOrIds string[]|openmw.types.IngredientRecord[] list of ingredient ids
---@return number weight
Alchemy.getPotionWeight = function(recordsOrIds)
    if not recordsOrIds or #recordsOrIds <= 0 then return 0 end
    local weight = 0
    for i = 1, #recordsOrIds do
        local record = Alchemy.toIngredientRecord(recordsOrIds[i])
        if record then
            weight = weight + record.weight
        end
    end

    return weight / #recordsOrIds
end

---@param ingredients string[]
---@return string
Alchemy.getIngredientsKey = function(ingredients)
    return table.concat(ingredients, ':')
end

---@param recordsOrIds string[]|openmw.types.IngredientRecord[] ordered list of ingredient ids
---@param actor openmw.LObject|openmw.GObject|nil actor to test the effect knowledge for - omit to assume full knowledge
---@return openmw.core.MagicEffectWithParams[] effects, table<integer, boolean> knowledge ordered list of matching effect ids and map of which effects are known
Alchemy.getMatchingEffects = function(recordsOrIds, actor)
    ---@type openmw.core.MagicEffectWithParams[]
    local effects = {}
    local knowledge = {}

    local knownCount = Alchemy.getKnownAlchemyEffectCount(actor, true)
    for i = 1, #recordsOrIds do
        local ingredient = Alchemy.toIngredientRecord(recordsOrIds[i])
        local known = Alchemy.getKnownEffectFlagsForIngredient(ingredient, actor)

        if ingredient then
            for j = i + 1, #recordsOrIds do
                local ingredient2 = Alchemy.toIngredientRecord(recordsOrIds[j])
                local known2 = Alchemy.getKnownEffectFlagsForIngredient(ingredient2, actor)
                if ingredient2 then
                    for k = 1, #ingredient.effects do
                        local effect = ingredient.effects[k]
                        local e = Alchemy.containsEffect(effects, effect)
                        local m = not e and Alchemy.containsEffect(ingredient2.effects, effect)
                        if e then
                            knowledge[e] = knowledge[e] or known[k]
                        elseif m ~= nil then
                            table.insert(effects, effect)
                            if config.main.b_ReplacePotionKnowledge then
                                table.insert(knowledge, known[k] or known2[m])
                            else
                                table.insert(knowledge, knownCount >= #effects) -- OpenMW shows known matching effect as if this was ready potion
                            end
                        end
                    end
                end
            end
        end
    end

    return effects, knowledge
end

Alchemy.effectKey = function(effect)
    return effect.id
        .. ':' .. tostring(effect.affectedAttribute)
        .. ':' .. tostring(effect.affectedSkill)
end

---@param recordsOrIds string[]|openmw.types.IngredientRecord[] ordered list of ingredient ids
---@param actor openmw.LObject|openmw.GObject|nil actor to test the effect knowledge for - omit to assume full knowledge
---@return openmw.core.MagicEffectWithParams[] effects, table<integer, boolean> knowledge ordered list of matching effect ids and map of which effects are known
Alchemy.getNonMatchingEffects = function(recordsOrIds, actor)
    ---@type openmw.core.MagicEffectWithParams[]
    local effects = {}
    local knowledge = {}
    local all = {}

    for i = 1, #recordsOrIds do
        local ingredient = Alchemy.toIngredientRecord(recordsOrIds[i])
        local known = Alchemy.getKnownEffectFlagsForIngredient(ingredient, actor)
        if ingredient then
            for k = 1, #ingredient.effects do
                local effect = ingredient.effects[k]
                local key = Alchemy.effectKey(effect)
                if all[key] then
                    local pos = Alchemy.containsEffect(effects, effect)
                    if pos then
                        table.remove(effects, pos)
                        table.remove(knowledge, pos)
                    end
                else
                    table.insert(effects, effect)
                    table.insert(knowledge, known[k])
                end
                all[key] = true
            end
        end
    end

    return effects, knowledge
end

---@param actor openmw.LObject|openmw.GObject|nil
---@return number
Alchemy.getAlchemyFactor = function(actor)
    if not actor or not actor.type or not actor.type.stats
        or not actor.type.stats.skills or not actor.type.stats.skills.alchemy
        or not actor.type.stats.attributes or not actor.type.stats.attributes.intelligence or not actor.type.stats.attributes.luck
    then
        return 0
    end

    --this formula is directly from OpenMW sources
    local alchemy = actor.type.stats.skills.alchemy(actor).modified
    local intelligence = actor.type.stats.attributes.intelligence(actor).modified
    local luck = actor.type.stats.attributes.luck(actor).modified

    return alchemy + 0.1 * intelligence + 0.1 * luck
end

---@param value number
---@param alembic openmw.types.ApparatusRecord?
---@param calcinator openmw.types.ApparatusRecord?
---@param retort openmw.types.ApparatusRecord?
---@return number
Alchemy.applyTools = function(value, alembic, calcinator, retort, hasMagnitude, hasDuration, isNegative)
    local tool = isNegative and alembic or retort
    local setup = 0

    --these formulas are directly from OpenMW sources
    if tool and calcinator then
        setup = 1
    elseif tool then
        setup = 2
    elseif calcinator then
        setup = 3
    else
        return value --no apparatus - no changes
    end
    local toolQuality = tool and tool.quality or 0
    local calcinatorQuality = calcinator and calcinator.quality or 0

    local quality = 1
    if setup == 1 then --both tools
        if isNegative then
            quality = 2 * toolQuality + 3 * calcinatorQuality
        elseif hasMagnitude and hasDuration then
            quality = 2 * toolQuality + calcinatorQuality
        else
            quality = 2 / 3.0 * (toolQuality + calcinatorQuality) + 0.5
        end
    elseif setup == 2 then --only main tool
        if isNegative then
            quality = 1 + toolQuality
        elseif hasMagnitude and hasDuration then
            quality = toolQuality
        else
            quality = toolQuality + 0.5
        end
    elseif setup == 3 then --only calcinator
        if hasMagnitude and hasDuration then
            quality = calcinatorQuality
        else
            quality = calcinatorQuality + 0.5
        end
    end

    if setup == 3 or not isNegative then
        value = value + quality
    else
        value = value / quality;
    end

    return value
end

---Returns `str` with spaces in front and end trimmed
---@param str string
---@return string
local function trim(str)
    return str:match("^%s*(.-)%s*$")
end

local function roundToPlaces(num, places)
    local mult = 10 ^ (places or 0)
    return math.floor(num * mult + 0.5) / mult
end

local parts = { "bargain", "cheap", "standard", "fresh", "quality", "exclusive" }

---Returns icon and model based on passed number, or randomly if number is not passed
---@param n number?
---@return string model, string  icon
Alchemy.selectPotionArt = function(n)
    if not n or type(n) ~= "number" then
        n = math.random(1, #parts)
    else
        n = util.clamp(util.round(n), 1, #parts)
    end

    local part = parts[n]
    local mModel = ("meshes/m/misc_potion_%s_01.nif"):format(part)
    local mIcon = ("icons/m/tx_potion_%s_01.dds"):format(part)
    return mModel, mIcon
end

---Returns potion stats based on ingredients, apparatus and actor skills
---@param name string potion name
---@param ingredientIds string[] ordered list of ingredient ids
---@param apparatus LocalApparatusIds info about apparatus being used
---@param actor openmw.LObject|openmw.GObject|nil
---@param opts {isPoison: boolean?}|nil
---@return openmw.types.PotionRecord record, AlchemyPotionErrors code, boolean[] knowledge
Alchemy.getPotionStats = function(name, ingredientIds, apparatus, actor, opts)
    ---@type openmw.core.MagicEffectWithParams[]
    local effects = {}
    local known = {}
    name = name and trim(name)
    local factor = Alchemy.getAlchemyFactor(actor)
    -- local model, icon = Alchemy.selectPotionArt(factor / 20) --TODO: add option to select model based on effective skill
    local model, icon = Alchemy.selectPotionArt()
    ---@type openmw.types.PotionRecord
    local stats = {
        id = '',
        name = name,
        effects = effects,
        model = model,
        icon = icon,
        value = 0,
        weight = 0,
        isAutocalc = false,
        mwscript = nil,
    }
    if #ingredientIds < 2 then return stats, Alchemy.PotionErrors.TOO_FEW_INGREDIENTS, known end
    local mortar = apparatus.Mortar and types.Apparatus.record(apparatus.Mortar)
    if not mortar then return stats, Alchemy.PotionErrors.NO_MORTAR, known end
    if not name or #name <= 0 then return stats, Alchemy.PotionErrors.NO_NAME, known end

    local ingredients = Alchemy.toIngredientRecords(ingredientIds)
    local matching, matchingKnowledge = Alchemy.getMatchingEffects(ingredients, actor)
    if #matching <= 0 then return stats, Alchemy.PotionErrors.FAIL, known end
    factor = factor * mortar.quality
    factor = factor * core.getGMST('fPotionStrengthMult')

    stats.value = util.round(factor * core.getGMST('iAlchemyMod'))
    stats.weight = roundToPlaces(Alchemy.getPotionWeight(ingredients), 4)
    local knownCount = Alchemy.getKnownAlchemyEffectCount(actor, true)

    local fPotionT1MagMul = core.getGMST('fPotionT1MagMult')
    if fPotionT1MagMul <= 0 then error('invalid gmst: fPotionT1MagMul') end

    local fPotionT1DurMult = core.getGMST('fPotionT1DurMult')
    if fPotionT1DurMult <= 0 then error('invalid gmst: fPotionT1DurMult') end

    local alembic = apparatus.Alembic and types.Apparatus.record(apparatus.Alembic)
    local calcinator = apparatus.Calcinator and types.Apparatus.record(apparatus.Calcinator)
    local retort = apparatus.Retort and types.Apparatus.record(apparatus.Retort)

    local idx = 1
    for i = 1, #matching do
        local effect = matching[i]
        ---@type openmw.core.MagicEffect?
        local effectRecord = Alchemy.getEffectRecord(effect.id)

        if not effectRecord or effectRecord.baseCost <= 0 then
            error("invalid base cost for magic effect '" .. effect.id .. "'")
        end

        local hasMagnitude = effectRecord.hasMagnitude
        local hasDuration = effectRecord.hasDuration
        local harmful = effectRecord.harmful

        if opts and opts.isPoison then
            harmful = not harmful
        end

        local magnitude = 1
        if hasMagnitude then
            magnitude = factor / fPotionT1MagMul / effectRecord.baseCost
            magnitude = Alchemy.applyTools(magnitude, alembic, calcinator, retort,
                hasMagnitude, hasDuration, harmful)
            magnitude = util.round(magnitude)
        end

        local duration = 1
        if hasDuration then
            duration = factor / fPotionT1DurMult / effectRecord.baseCost
            duration = Alchemy.applyTools(duration, alembic, calcinator, retort,
                hasMagnitude, hasDuration, harmful)
            duration = util.round(duration)
        end

        if magnitude > 0 and duration > 0 then
            ---@type openmw.core.MagicEffectWithParams
            local newEffect = {
                effect = effectRecord,
                id = effect.id,
                affectedSkill = effect.affectedSkill,
                affectedAttribute = effect.affectedAttribute,
                range = 0,
                area = 0,
                magnitudeMin = magnitude,
                magnitudeMax = magnitude,
                duration = duration,
                index = idx,
            }
            idx = idx + 1
            table.insert(effects, newEffect)
            if config.main.b_ReplacePotionKnowledge then
                table.insert(known, matchingKnowledge[i])
            else
                table.insert(known, #effects <= knownCount)
            end
        end
    end

    return stats, #effects <= 0 and Alchemy.PotionErrors.FAIL or Alchemy.PotionErrors.OK, known
end

---@param alchemyFactor number
---@return boolean success
Alchemy.checkPotionBrewSuccess = function(alchemyFactor)
    return alchemyFactor >= math.random(0, 99)
end

---@param a openmw.core.MagicEffectWithParams[]
---@param b openmw.core.MagicEffectWithParams[]
local function potionEffectsEqual(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        local ea = a[i]
        local eb = b[i]
        if ea.id ~= eb.id
            or ea.affectedAttribute ~= eb.affectedAttribute
            or ea.affectedSkill ~= ea.affectedSkill
            or ea.duration ~= eb.duration
            or ea.magnitudeMin ~= eb.magnitudeMin
            or ea.magnitudeMax ~= eb.magnitudeMax
            or ea.range ~= ea.range
            or ea.area ~= ea.area
        then
            return false
        end
    end
    return true
end

---@class PotionCompareOpts
---@field ignore {icon:boolean?, model:boolean? } which properties to ignore when comparing? Id is always ignored.
---@field generated boolean? if true, will look only among dynamically generated records

---@param a openmw.types.PotionRecord
---@param b openmw.types.PotionRecord
---@param opts PotionCompareOpts?
local function potionRecordsEqual(a, b, opts)
    local ignoreIcon = false
    local ignoreModel = false
    if opts and opts.ignore then
        ignoreIcon = opts.ignore.icon
        ignoreModel = opts.ignore.model
    end

    if a.name ~= b.name then return false end
    if math.floor(10000 * a.weight) ~= math.floor(10000 * b.weight) then return false end
    if a.value ~= b.value then return false end
    if a.mwscript ~= b.mwscript then return false end
    if not ignoreIcon and a.icon ~= b.icon then return false end
    if not ignoreModel and a.model ~= b.model then return false end
    if a.isAutocalc ~= b.isAutocalc then return false end
    if not potionEffectsEqual(a.effects, b.effects) then return false end
    return true
end

---@param record openmw.types.PotionRecord
---@param opts PotionCompareOpts?
---@return openmw.types.PotionRecord?
Alchemy.findPotion = function(record, opts)
    local generated = opts and opts.generated
    for i = 1, #types.Potion.records do
        ---@type openmw.types.PotionRecord
        local potion = types.Potion.records[i]
        if not generated or isGeneratedId(potion.id) then
            if potionRecordsEqual(record, potion, opts) then return potion end
        end
    end
    return nil
end

---@param actor openmw.LObject|openmw.GObject|nil
---@return integer
Alchemy.getKnownAlchemyEffectCount = function(actor, isPotion)
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

---Returns map of effect index to whether actor knows this effect. If actor is omitted - assume we know all effects.
---@param ingredient string|openmw.types.IngredientRecord|nil
---@param actor openmw.LObject|openmw.GObject|nil
---@return table<integer, boolean>
Alchemy.getKnownEffectFlagsForIngredient = function(ingredient, actor)
    ingredient = Alchemy.toIngredientRecord(ingredient)
    if not ingredient then return {} end
    local known = Alchemy.getKnownAlchemyEffectCount(actor, false)
    local knowledge = Alchemy.knowledge.ingredientKnowledge[ingredient.id]
    local result = {}
    for i = 1, #ingredient.effects do
        result[i] = i <= known
        if config.main.b_ReplacePotionKnowledge and knowledge then
            result[i] = result[i] or knowledge[i]
        end
    end
    return result
end

---Returns map of effect index to whether actor knows this effect. If actor is omitted - assume we know all effects.
---@param potion string|openmw.types.PotionRecord|nil
---@param actor openmw.LObject|openmw.GObject|nil
---@return table<integer, boolean>
Alchemy.getKnownEffectFlagsForPotion = function(potion, actor)
    potion = Alchemy.toPotionRecord(potion)
    if not potion then return {} end
    local known = Alchemy.getKnownAlchemyEffectCount(actor, true)
    local knowledge = Alchemy.knowledge.potionKnowledge[potion.id]
    local wasDrank = knowledge == true
    local result = {}

    local hasHarmful = false
    local hasGood = false
    for i = 1, #potion.effects do
        local effect = potion.effects[i]
        hasHarmful = hasHarmful or effect.effect.harmful
        hasGood = hasGood or not effect.effect.harmful
    end
    for i = 1, #potion.effects do
        local effect = potion.effects[i]
        if not config.main.b_ReplacePotionKnowledge then
            result[i] = i <= known
        else
            if wasDrank then
                result[i] = wasDrank
            elseif isGeneratedId(potion.id) then
                result[i] = type(knowledge) == "table" and knowledge[i]
            else
                local effectRecord = effect.effect or Alchemy.getEffectRecord(effect.id)
                result[i] = effectRecord and (not effectRecord.harmful or not hasGood)
            end
        end
    end
    return result
end

return Alchemy
