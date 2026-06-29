---@omw-context player

local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local player = require('openmw.self')

local I = require("openmw.interfaces")
local T = {
    Base    = require("scripts.UIToolkit.templates.base"),
    Special = require("scripts.UIToolkit.templates.special"),
}
local C = require("scripts.UIToolkit.constants")
local H = require("scripts.UIToolkit.helpers")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Window = require("scripts.UIToolkit.window")
local IngredientTable = require("scripts.TPABOBAP.AlchemyRedone.ui.ingredient_table")

local v2 = util.vector2

---@class IngredientWindow: Window
---@field protected ctx AlchemyContext
---@field private data AlchemyData
---@field private itemTable openmw.ui.Element?
local IngredientWindow = Window:new()

---@return IngredientWindow
function IngredientWindow:new()
    local r = Window.new(self)
    ---@cast r IngredientWindow
    return r
end

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

---@param ctx AlchemyContext
function IngredientWindow:init(ctx)
    self:setContext(ctx)
    self.data = ctx.data

    local rowHeight = 1.5 * (T.Base.TEXT_SIZE + 2)
    local effectWidth = 4 * (T.Base.TEXT_SIZE + 3)
    self.itemTable = IngredientTable.create(self.ctx, {
        columns = {
            { id = 'icon',    width = rowHeight + 5, renderer = renderIcon },
            { id = 'name', },
            { id = 'effects', width = effectWidth,   renderer = renderEffects },
        },
        data = self.ctx.getAllIngredients(),
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
        onRowUse = function(row, rowWidget)
            return self:onRowUse(row, rowWidget, false)
        end,

        onKBMRowUse = function(row, rowWidget)
            return self:onRowUse(row, rowWidget, true)
        end,
        tooltipFn = function(row) return T.Special.ingredientTooltip(row.id, player) end,
        parentWindow = self,
    })

    local content = ui.content {
        self.itemTable
    }
    self.element = T.Base.window(C.Strings.INGREDIENTS, content, self.ctx, {
        draggable = true,
        onDrag = function()
            self:updateSize()
        end
    })
    self.element.layout.userData.minWidth = 300
    self.element.layout.userData.minHeight = 100
    self:setDimensions({ x = 0.70, y = 0.15, w = 0.15, h = 0.5 })
    self:updateSize()
    --local sz = self.element.layout.userData.getInnerSize()
end

function IngredientWindow:update(deep)
    if not self.element then return end
    if deep then
        self.itemTable.layout.userData.redrawColumns()
    end
    Window.update(self, deep)
end

function IngredientWindow:updateData()
    if not self.element then return end
    self.itemTable.layout.userData.updateData(self.ctx.getAllIngredients())
end

function IngredientWindow:updateSize()
    if self.element then
        self.itemTable.layout.userData.resize(self.element.layout.userData.getInnerSize())
    end
end

function IngredientWindow:onRowUse(row, rowWidget, fromKBMKeybind)
    self.ctx.selectIngredient({ id = row.id, count = row.count })
    return false
end

return IngredientWindow
