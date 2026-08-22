---@omw-context runtime

local core = require 'openmw.core'
local util = require 'openmw.util'
local I = require 'openmw.interfaces'
local isPlayer, self = pcall(require, 'openmw.self')

local toolkitHelpers = require 'scripts.UIToolkit.helpers'

---@class AlchemyRedone.Constant.EffectStrings
local EffectStrings = {
    ABSORB = core.getGMST('sAbsorb'),
    DAMAGE = core.getGMST('sDamage'),
    DRAIN = core.getGMST('sDrain'),
    FORTIFY = core.getGMST('sFortify'),
    RESTORE = core.getGMST('sRestore'),
    TO = core.getGMST('sTo'),
    PERCENT = core.getGMST('spercent'),
    FEET = core.getGMST('sfeet'),
    POINT = core.getGMST('spoint'),
    POINTS = core.getGMST('spoints'),
    FOR = core.getGMST('sfor'),
    SECOND = core.getGMST('ssecond'),
    SECONDS = core.getGMST('sseconds'),
    LEVEL = core.getGMST('sLevel'),
    LEVELS = core.getGMST('sLevels'),
    X_TIMES_INT = core.getGMST('sXTimesInt'),
    ON = core.getGMST('sonword'),
    RANGE_SELF = core.getGMST('sRangeSelf'),
    RANGE_TOUCH = core.getGMST('sRangeTouch'),
    RANGE_TARGET = core.getGMST('sRangeTarget'),
    IN = core.getGMST('sin'),
    FOOT_AREA = core.getGMST('sfootarea'),
}

local MagnitudeDisplayType = {
    NONE = 1,
    TIMES_INT = 2,
    FEET = 3,
    LEVEL = 4,
    PERCENTAGE = 5,
    POINTS = 6,
}

---@class AlchemyRedone.Helpers
local H = {}

---@param id string effect id
---@return openmw.core.MagicEffect? record, boolean isCustom
function H.getMagicEffectRecord(id)
    ---@type openmw.core.MagicEffect?
    local effect = core.magic.effects.records[id]
    if effect then return effect, false end
    effect = I.MagicWindow and I.MagicWindow.Spells.getCustomEffect(id)
    if effect then return effect, true end
    return nil, false
end

---@param effectParams {id: string, affectedSkill: string?, affectedAttribute: string?}
---@return string
function H.getMagicEffectString(effectParams)
    local effect = H.getMagicEffectRecord(effectParams.id)
    if not effect then return effectParams.id end

    local affectedSkill = effectParams.affectedSkill
    local affectedAttribute = effectParams.affectedAttribute

    local string

    local TYPE = core.magic.EFFECT_TYPE
    if (affectedSkill or affectedAttribute) then
        if effect.id == TYPE.AbsorbAttribute or effect.id == TYPE.AbsorbSkill then
            string = EffectStrings.ABSORB
        elseif effect.id == TYPE.DamageAttribute or effect.id == TYPE.DamageSkill then
            string = EffectStrings.DAMAGE
        elseif effect.id == TYPE.DrainAttribute or effect.id == TYPE.DrainSkill then
            string = EffectStrings.DRAIN
        elseif effect.id == TYPE.FortifyAttribute or effect.id == TYPE.FortifySkill then
            string = EffectStrings.FORTIFY
        elseif effect.id == TYPE.RestoreAttribute or effect.id == TYPE.RestoreSkill then
            string = EffectStrings.RESTORE
        end
    end

    if not string then
        string = effect.name
    end

    if affectedSkill then
        local skill = core.stats.Skill.records[affectedSkill]
        string = string .. ' ' .. skill.name
    elseif affectedAttribute then
        local attribute = core.stats.Attribute.records[affectedAttribute]
        string = string .. ' ' .. attribute.name
    end

    return string
end

local magnitudeMap = {
    [MagnitudeDisplayType.TIMES_INT] = {
        fortifymaximummagicka = true,
    },
    [MagnitudeDisplayType.FEET] = {
        telekinesis = true,
        detectanimal = true,
        detectenchantment = true,
        detectkey = true,
    },
    [MagnitudeDisplayType.LEVEL] = {
        commandcreature = true,
        commandhumanoid = true,
    },
    [MagnitudeDisplayType.PERCENTAGE] = {
        chameleon = true,
        blind = true,
        dispel = true,
        reflect = true,
    },
}

function H.getEffectMagnitudeDisplayType(effect)
    if (not effect.maxMagnitude or not effect.minMagnitude) and not effect.hasMagnitude then
        return MagnitudeDisplayType.NONE
    end
    if magnitudeMap[MagnitudeDisplayType.TIMES_INT][effect.id] then
        return MagnitudeDisplayType.TIMES_INT
    end
    if magnitudeMap[MagnitudeDisplayType.FEET][effect.id] then
        return MagnitudeDisplayType.FEET
    end
    if magnitudeMap[MagnitudeDisplayType.LEVEL][effect.id] then
        return MagnitudeDisplayType.LEVEL
    end
    if magnitudeMap[MagnitudeDisplayType.PERCENTAGE][effect.id] or
        effect.id:find('^weakness') or
        effect.id:find('^resist') then
        return MagnitudeDisplayType.PERCENTAGE
    end
    return MagnitudeDisplayType.POINTS
end

---@param effectParams MagicEffectWithParams|{id: string, affectedSkill: string?, affectedAttribute: string?}
---@param isConstant boolean?
---@param hideRange boolean?
---@return string
function H.createSpellEffectString(effectParams, isConstant, hideRange)
    local effect, isCustom = H.getMagicEffectRecord(effectParams.id)
    if not effect then return '' end

    local string = H.getMagicEffectString(effectParams)

    if (effectParams.magnitudeMin or effectParams.magnitudeMax) and effect.hasMagnitude then
        local magnitudeType
        if isCustom then
            ---@diagnostic disable-next-line: undefined-field
            magnitudeType = effect.magnitudeType
        else
            magnitudeType = H.getEffectMagnitudeDisplayType(effect)
        end

        if magnitudeType == MagnitudeDisplayType.TIMES_INT then
            string = string .. ' ' .. toolkitHelpers.roundToPlaces(effectParams.magnitudeMin / 10.0, 1)
            if effectParams.magnitudeMin ~= effectParams.magnitudeMax then
                string = string ..
                    ' ' .. EffectStrings.TO .. ' ' .. toolkitHelpers.roundToPlaces(effectParams.magnitudeMax / 10.0, 1)
            end
            string = string .. EffectStrings.X_TIMES_INT
        elseif magnitudeType ~= MagnitudeDisplayType.NONE then
            string = string .. ' ' .. tostring(effectParams.magnitudeMin)
            if effectParams.magnitudeMin ~= effectParams.magnitudeMax then
                string = string .. ' ' .. EffectStrings.TO .. ' ' .. tostring(effectParams.magnitudeMax)
            end

            if magnitudeType == MagnitudeDisplayType.PERCENTAGE then
                string = string .. EffectStrings.PERCENT
            elseif magnitudeType == MagnitudeDisplayType.FEET then
                string = string .. ' ' .. EffectStrings.FEET
            elseif magnitudeType == MagnitudeDisplayType.LEVEL then
                string = string .. ' '
                if effectParams.magnitudeMin == effectParams.magnitudeMax and math.abs(effectParams.magnitudeMin) == 1 then
                    string = string .. EffectStrings.LEVEL
                else
                    string = string .. EffectStrings.LEVELS
                end
            else -- POINTS
                string = string .. ' '
                if effectParams.magnitudeMin == effectParams.magnitudeMax and math.abs(effectParams.magnitudeMin) == 1 then
                    string = string .. EffectStrings.POINT
                else
                    string = string .. EffectStrings.POINTS
                end
            end
        end
    end

    if not isConstant then
        local duration = effectParams.duration or 0

        if not effect.isAppliedOnce then
            duration = math.max(1, duration)
        end

        if duration > 0 and effect.hasDuration then
            string = string .. ' ' .. EffectStrings.FOR .. ' ' .. tostring(duration) .. ' '
            if duration == 1 then
                string = string .. EffectStrings.SECOND
            else
                string = string .. EffectStrings.SECONDS
            end
        end

        if effectParams.area > 0 then
            string = string ..
                ' ' .. EffectStrings.IN .. ' ' .. tostring(effectParams.area) .. ' ' .. EffectStrings.FOOT_AREA
        end

        if not hideRange then
            string = string .. ' ' .. EffectStrings.ON .. ' '
            if effectParams.range == core.magic.RANGE.Self then
                string = string .. EffectStrings.RANGE_SELF
            elseif effectParams.range == core.magic.RANGE.Touch then
                string = string .. EffectStrings.RANGE_TOUCH
            else
                string = string .. EffectStrings.RANGE_TARGET
            end
        end
    end

    return string
end

if isPlayer then
    ---@omw-context-begin player
    local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")


    ---@param itemRecord openmw.types.IngredientRecord
    ---@param actor openmw.GObject|openmw.LObject|nil
    ---@return {effect:openmw.core.MagicEffectWithParams, visible: boolean, text: string?}[]
    function H.getTooltipIngredientEffectEntries(itemRecord, actor)
        local effectsToShow = {}
        local known = A.getKnownEffectFlagsForIngredient(itemRecord, actor)
        for i = 1, #itemRecord.effects do
            local effect = itemRecord.effects[i]
            if effect then -- Some TR Data ingredients have gaps in effects
                local isVisible = known[i]
                local effectText = nil
                if isVisible then
                    effectText = H.getMagicEffectString(effect)
                end

                table.insert(effectsToShow, {
                    effect = effect,
                    visible = isVisible,
                    text = effectText,
                })
            end
        end

        return effectsToShow
    end

    ---@omw-context-end player
end
return H
