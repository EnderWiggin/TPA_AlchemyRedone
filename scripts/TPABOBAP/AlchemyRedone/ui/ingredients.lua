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

local IngredientTable = require("scripts.TPABOBAP.AlchemyRedone.ui.item_table")


local m = {}

local function renderIcon(ingredient, width, height)
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

m.makeTable = function(wnd)
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
            if #effects >= i then
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

    return IngredientTable.create(ctx, {
        columns = {
            { id = 'icon',    width = rowHeight + 5, renderer = renderIcon },
            { id = 'name', },
            { id = 'effects', width = effectWidth,   renderer = renderEffects },
        },
        data = ctx.getAllIngredients(),
        size = v2(600, 400),
        rowHeight = rowHeight,
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

        onKBMRowUse = function(row)
            return ctx.selectIngredient({ id = row.id, count = row.count })
        end,
        tooltipFn = function(row) return T.Special.ingredientTooltip(row.id, player) end,
        parentWindow = wnd,
    })
end

m.getSearchText = function(recordOrId, actor)
    local record = A.toIngredientRecord(recordOrId)
    if not record then return '' end

    local searchParts = { record.name }

    for i, effectData in ipairs(H.getTooltipIngredientEffectEntries(record, actor)) do
        if effectData.visible and effectData.text and effectData.text ~= '' then
            table.insert(searchParts, effectData.text)
        end
    end

    return table.concat(searchParts, '\n'):lower()
end


return m
