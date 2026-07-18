---@omw-context player

local types = require("openmw.types")
local util = require('openmw.util')
local ui = require('openmw.ui')
local player = require('openmw.self')

local v2 = util.vector2
local T = {
    Base    = require("scripts.TPABOBAP.UIToolkit.templates.base"),
    Special = require("scripts.TPABOBAP.UIToolkit.templates.special"),
}
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")
local H = require("scripts.TPABOBAP.UIToolkit.helpers")
local C = require("scripts.TPABOBAP.UIToolkit.constants")

local Table = require("scripts.TPABOBAP.AlchemyRedone.ui.item_table")

---@class IngredientItemData : BaseItemData
---@field count integer

---@class EffectItemData : BaseItemData
---@field effectId string
---@field affectedAttribute string?
---@field affectedSkill string?
---@field isFavorite fun():boolean
---@field count integer

local m = {}

local function renderIngredientIcon(ingredient, width, height)
    local record = types.Ingredient.record(ingredient.id)
    local sz = math.min(width, height)
    return {
        name = 'Icon',
        props = {
            size = v2(width, height),
        },
        content = ui.content {
            {
                name = 'icon',
                type = ui.TYPE.Image,
                props = {
                    resource = record and T.Base.createTexture(record.icon),
                    anchor = v2(0.5, 0.5),
                    relativePosition = v2(0.5, 0.5),
                    size = v2(sz, sz),
                }
            },
        }
    }
end

---@param effect EffectItemData
---@param width number
---@param height number
local function renderEffectIcon(effect, width, height)
    local sz = math.min(width, height) - 5
    return {
        name = 'Icon',
        props = {
            size = v2(width, height),
        },
        content = ui.content {
            {
                name = 'icon',
                type = ui.TYPE.Image,
                props = {
                    resource = T.Base.effectIconTexture(effect.effectId),
                    anchor = v2(0.5, 0.5),
                    relativePosition = v2(0.5, 0.5),
                    size = v2(sz, sz),
                }
            },
        }
    }
end

---@param effect EffectItemData
---@param width number
---@param height number
local function renderFavoriteEffect(effect, width, height)
    if not effect.isFavorite() then return { props = {} } end
    return {
        name = 'Favorite',
        props = {
            size = v2(width, height),
        },
        content = ui.content {
            {
                template = T.Base.textNormal,
                props = {
                    text = '*',
                    textSize = T.Base.TEXT_SIZE * 2,
                    textColor = C.Colors.YELLOW,
                    textAlignH = ui.ALIGNMENT.Center,
                    textAlignV = ui.ALIGNMENT.Center,
                    anchor = v2(0.5, 0.5),
                    relativePosition = v2(0.5, 0.5),
                },
            }
        }
    }
end

m.makeIngredientTable = function(wnd)
    ---@type AlchemyContext
    local ctx = wnd.ctx
    ---@type AlchemyData
    local data = wnd.data
    local rowHeight = 1.5 * (T.Base.TEXT_SIZE + 2)
    local effectWidth = 4 * (T.Base.TEXT_SIZE + 3)

    local function renderEffects(ingredient, width, height)
        local record = types.Ingredient.record(ingredient.id)
        local effects = record and record.effects or {}
        local sz = T.Base.TEXT_SIZE
        local content = ui.content {}
        local known = A.getKnownEffectFlagsForIngredient(record, player)
        local nonMatching = data.nonMatching
        local notActive = not ingredient.activeFn()
        local brightKey = {}
        local knownKey = {}

        for i = 1, 4 do
            if #effects >= i and effects[i] then
                local effect = effects[i]
                local bright = known[i]
                if bright and nonMatching and #nonMatching > 0 then
                    local idx = A.containsEffect(nonMatching, effect)
                    bright = idx ~= nil and data.nonMatchingKnowledge[idx] and notActive
                end
                content:add({
                    name = 'effect_' .. i,
                    type = ui.TYPE.Image,
                    props = {
                        resource = known[i] and T.Base.effectIconTexture(effect.id) or T.Special.TEX.UNKNOWN_EFFECT,
                        anchor = v2(0, 0.5),
                        relativePosition = v2(0, 0.5),
                        position = v2((sz + 3) * (i - 1), 0),
                        size = v2(sz, sz),
                        alpha = bright and 1 or 0.5
                    }
                })
                table.insert(brightKey, tostring(bright))
                table.insert(knownKey, tostring(known[i]))
            end
        end
        return {
            name = 'Effects',
            props = {
                size = v2(width, height),
            },
            content = content,
            userData = {
                brightKey = table.concat(brightKey, ':'),
                knownKey = table.concat(knownKey, ':'),
            }
        }
    end

    return Table.create(ctx, {
        columns = {
            { id = 'icon',    width = rowHeight + 5, renderer = renderIngredientIcon },
            { id = 'name', },
            { id = 'effects', width = effectWidth,   renderer = renderEffects },
        },
        data = ctx.getAllIngredients(),
        size = v2(600, 400),
        rowHeight = rowHeight,
        ---@param a IngredientItemData
        ---@param b IngredientItemData
        ---@return boolean
        comparator = function(a, b)
            local rA = types.Ingredient.record(a.id)
            local rB = types.Ingredient.record(b.id)

            if rA ~= nil and rB ~= nil then
                if rA.name ~= rB.name then return rA.name < rB.name end
            elseif rA == nil then
                return false
            elseif rB == nil then
                return true
            end

            return a.id < b.id
        end,
        onRowUse = function(row)
            return ctx.selectIngredient({ id = row.id, count = row.count })
        end,

        tooltipFn = function(row) return T.Special.ingredientTooltip(row.id, player) end,
        parentWindow = wnd,
    })
end

m.effectDataToEffect = function(data)
    return {
        id = data.effectId,
        affectedAttribute = data.affectedAttribute,
        affectedSkill = data.affectedSkill,
    }
end

---@param wnd AlchemyWindow
m.makeEffectTable = function(wnd)
    ---@type AlchemyContext
    local ctx = wnd.ctx
    local rowHeight = 1.5 * (T.Base.TEXT_SIZE + 2)

    return Table.create(ctx, {
        columns = {
            { id = 'icon',       width = rowHeight + 5, renderer = renderEffectIcon },
            { id = 'displayName', },
            { id = 'isFavorite', width = rowHeight,     renderer = renderFavoriteEffect },
        },
        data = ctx.getAllEffects(),
        size = v2(600, 400),
        rowHeight = rowHeight,
        ---@param a EffectItemData
        ---@param b EffectItemData
        ---@return boolean
        comparator = function(a, b)
            local fA = a.isFavorite()
            local fB = b.isFavorite()

            if fA ~= fB then
                if fA then
                    return true
                else
                    return false
                end
            end

            local rA = A.getEffectRecord(a.effectId)
            local rB = A.getEffectRecord(b.effectId)

            local nA = rA and rA.name
            local nB = rB and rB.name

            if nA ~= nB then
                if not nA then return false end
                if not nB then return true end
                return nA < nB
            end

            nA = H.getMagicEffectString(m.effectDataToEffect(a))
            nB = H.getMagicEffectString(m.effectDataToEffect(b))

            if nA == nB then return a.id < b.id end
            return nA < nB
        end,
        onRowUse = function(row) wnd:onEffectClicked(row) end,

        ---@param row EffectItemData
        ---@return openmw.ui.Layout
        tooltipFn = function(row) return T.Special.magicEffectTooltip(row.effectId) end,
        parentWindow = wnd,
    })
end

m.getIngredientSearchText = function(recordOrId, actor)
    local record = A.toIngredientRecord(recordOrId)
    if not record then return '' end

    local searchParts = { record.name }

    for i, effectData in ipairs(H.getTooltipIngredientEffectEntries(record, actor)) do
        if effectData.visible and effectData.text and effectData.text ~= '' then
            table.insert(searchParts, '"' .. effectData.text .. '"')
        end
    end

    return table.concat(searchParts, '\n'):lower()
end

local function textNormal(name, text)
    return { name = name, template = T.Base.textNormal, props = { text = text } }
end

m.getIEMagicEffectsContent = function(item, actor)
    local effectsToShow = H.getTooltipMagicEffectEntries(item, actor)

    -- Build effect layouts if we have any effects
    if #effectsToShow > 0 then
        local effectLayouts = {}
        for i, effectData in ipairs(effectsToShow) do
            local effect = effectData.effect
            local isVisible = effectData.visible
            local content = ui.content {}

            if isVisible then
                content:add(T.Special.effectIcon(effect.id))
                content:add(T.Base.intervalH(4))
                local effectText = effectData.text or '?'
                content:add(textNormal('effect_' .. i, effectText))
            else
                content:add(textNormal('effect_' .. i, '?'))
            end

            local effectLayout = {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = content,
            }

            if i ~= 1 then
                table.insert(effectLayouts, T.Base.intervalV(8))
            end
            table.insert(effectLayouts, effectLayout)
        end

        return ui.content { table.unpack(effectLayouts) }
    end
    return ui.content {}
end

return m
