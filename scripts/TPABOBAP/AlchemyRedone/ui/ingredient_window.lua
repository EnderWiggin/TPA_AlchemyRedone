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

---@param ctx AlchemyContext
function IngredientWindow:init(ctx)
    self:setContext(ctx)
    self.data = ctx.data

    self.itemTable = self.ctx.makeIngredientsTable(self)

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
    if not self.element then return end
    local inner = self.element.layout.userData.getInnerSize()
    if self.lastSz and self.lastSz == inner then return end
    self.lastSz = inner
    self.itemTable.layout.userData.resize(inner)
end

function IngredientWindow:onRowUse(row, rowWidget, fromKBMKeybind)
    self.ctx.selectIngredient({ id = row.id, count = row.count })
    return false
end

return IngredientWindow
