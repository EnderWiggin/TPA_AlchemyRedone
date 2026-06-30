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

local function renderEffects(ingredient, width, height)
    local record = types.Ingredient.record(ingredient.id)
    local effects = record and record.effects or {}
    local sz = T.Base.TEXT_SIZE
    local content = ui.content {}
    local known = A.getKnownEffectFlagsForIngredient(record, player)
    for i = 1, 4 do
        if #effects >= i then
            content:add({
                name = 'effect_' .. i,
                type = ui.TYPE.Image,
                props = {
                    resource = known[i] and T.Base.effectIconTexture(effects[i].id) or T.Special.TEX.UNKNOWN_EFFECT,
                    anchor = v2(0, 0.5),
                    relativePosition = v2(0, 0.5),
                    position = v2((sz + 3) * (i - 1), 0),
                    size = v2(sz, sz),
                }
            })
        end
    end

    return {
        name = 'Effects',
        props = {
            size = v2(width, height),
        },
        content = content
    }
end

m.makeTable = function(wnd)
    ---@type AlchemyContext
    local ctx = wnd.ctx
    local rowHeight = 1.5 * (T.Base.TEXT_SIZE + 2)
    local effectWidth = 4 * (T.Base.TEXT_SIZE + 3)

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

m.getSearchText = function(recordOrId)
    local record = A.toIngredientRecord(recordOrId)
    if not record then return '' end

    local searchParts = { record.name }

    for _, effectData in ipairs(H.getTooltipIngredientEffectEntries(record)) do
        if effectData.visible and effectData.text and effectData.text ~= '' then
            table.insert(searchParts, effectData.text)
        end
    end

    return table.concat(searchParts, '\n'):lower()
end


return m
