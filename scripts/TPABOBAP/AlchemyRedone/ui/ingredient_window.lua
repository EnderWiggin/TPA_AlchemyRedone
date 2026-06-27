---@omw-context player

local core = require("openmw.core")
local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local async = require('openmw.async')

local I = require("openmw.interfaces")
local T = require("scripts.UIToolkit.templates.base")
local C = require("scripts.UIToolkit.constants")
local H = require("scripts.UIToolkit.helpers")

local Window = require("scripts.UIToolkit.window")
local IngredientTable = require("scripts.TPABOBAP.AlchemyRedone.ui.ingredient_table")

local MWUI = I.MWUI.templates
local v2 = util.vector2

---@class IngredientWindow: Window
---@field protected ctx AlchemyContext
---@field private data table?
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
                    resource = record and T.createTexture(record.icon),
                    anchor = v2(0.5, 0.5),
                    relativePosition = v2(0.5, 0.5),
                    size = v2(sz, sz),
                }
            },
        }
    }
end

local function renderName(ingredient, width, height)
    local record = types.Ingredient.record(ingredient.id)
    local name = record and record.name .. ' (' .. H.addSeparators(ingredient.count) .. ')' or C.Strings.NONE
    return {
        name = 'ingredientName',
        template = T.textNormal,
        props = {
            text = name,
            size = v2(width, height),
            textAlignH = ui.ALIGNMENT.Start,
            textAlignV = ui.ALIGNMENT.Center,
            autoSize = false,
        },
        userData = {
            colorable = true,
        }
    }
end

local function renderEffects(ingredient, width, height)
    local record = types.Ingredient.record(ingredient.id)
    local effects = record and record.effects or {}
    local sz = T.TEXT_SIZE
    local content = ui.content {}
    for i = 1, 4 do
        if #effects >= i then
            --TODO: account for unknown effects
            content:add({
                name = 'effect_' .. i,
                type = ui.TYPE.Image,
                props = {
                    resource = T.effectIconTexture(effects[i].id),
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

    local rowHeight = 1.5 * (T.TEXT_SIZE + 2)
    local effectWidth = 4 * (T.TEXT_SIZE + 3)
    self.itemTable = IngredientTable.create(self.ctx, {
        columns = {
            { id = 'icon',    width = rowHeight + 5, renderer = renderIcon },
            { id = 'name', },
            { id = 'effects', width = effectWidth,   renderer = renderEffects },
        },
        data = self:getAllIngredients(),
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

        parentWindow = self,
    })

    local content = ui.content {
        self.itemTable
    }
    self.ctx.minWidth = 250
    self.ctx.minHeight = 300
    self.element = T.window(C.Strings.INGREDIENTS, content, self.ctx, {
        draggable = true,
        onDrag = function()
            self:updateSize()
        end
    })
    self:setDimensions({ x = 0.66, y = 0.15, w = 0.15, h = 0.5 })
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

function IngredientWindow:getAllIngredients()
    if not self.data or not self.data.ingredients then
        return {}
    end
    local map = {}
    for _, list in pairs(self.data.ingredients) do
        for i = 1, #list do
            local ingredient = list[i]
            map[ingredient.id] = (map[ingredient.id] or 0) + ingredient.count
        end
    end
    local result = {}
    for id, count in pairs(map) do
        local record = types.Ingredient.record(id)
        local name = record and record.name .. ' (' .. H.addSeparators(count) .. ')' or C.Strings.NONE
        table.insert(result, {
            id = id,
            count = count,
            name = name,
            activeFn = function()
                if self.data and self.data.selected then
                    for i = 1, 4 do
                        local itm = self.data.selected[i]
                        if itm and itm.id == id then return true end
                    end
                end
                return false
            end,
        })
    end
    return result
end

function IngredientWindow:updateSize()
    if self.element then
        self.itemTable.layout.userData.resize(self.element.layout.userData.getInnerSize())
    end
end

function IngredientWindow:onRowUse(row, rowWidget, fromKBMKeybind)
    print('onRowUse', row.id, fromKBMKeybind)
    self.ctx.selectIngredient({ id = row.id, count = row.count })
    return false
end

return IngredientWindow
