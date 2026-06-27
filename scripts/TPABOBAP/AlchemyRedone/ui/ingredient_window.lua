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
    local effectWidth = 85 --4 * (T.TEXT_SIZE + 2)
    self.itemTable = IngredientTable.create(self.ctx, {
        columns = {
            { id = 'icon',    width = rowHeight + 5, renderer = renderIcon },
            { id = 'name',    renderer = renderName },
            { id = 'effects', width = effectWidth,   renderer = renderEffects },
            --{ id = 'count',   width = 64 },
        },
        data = { --TODO: get from actual data
            { id = 'ingred_wickwheat_01',   count = 10 },
            { id = 'ingred_marshmerrow_01', count = 100 },
        },
        size = v2(600, 400),
        rowHeight = rowHeight,

        onRowUse = nil,

        onKBMRowUse = function(row, rowWidget)
            --return onRowUse(row, rowWidget, true)
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

function IngredientWindow:updateSize()
    if self.element then
        self.itemTable.layout.userData.resize(self.element.layout.userData.getInnerSize())
    end
end

return IngredientWindow
