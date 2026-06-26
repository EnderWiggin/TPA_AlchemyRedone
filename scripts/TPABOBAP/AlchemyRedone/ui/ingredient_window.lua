---@omw-context player

local core = require("openmw.core")
local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local async = require('openmw.async')

local I = require("openmw.interfaces")
local T = require("scripts.UIToolkit.templates")
local C = require("scripts.UIToolkit.constants")
local H = require("scripts.UIToolkit.helpers")

local Window = require("scripts.UIToolkit.window")

local MWUI = I.MWUI.templates
local v2 = util.vector2

---@class IngredientWindow: Window
---@field private data table?
local IngredientWindow = Window:new()

---@return IngredientWindow
function IngredientWindow:new()
    local r = Window.new(self)
    ---@cast r IngredientWindow
    return r
end

function IngredientWindow:init(data)
    self.data = data
    local content = ui.content {
        {
            name = 'main',
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
            },
            content = ui.content {
                T.intervalH(5),
                {
                    name = 'left',
                    type = ui.TYPE.Flex,
                    props = {},
                    content = ui.content {

                    }
                },
            }
        },
    }
    self.ctx.minWidth = 250
    self.ctx.minHeight = 300
    self.element = T.window(C.Strings.INGREDIENTS, content, self.ctx, { draggable = true })
    self:setDimensions({ x = 0.66, y = 0.15, w = 0.15, h = 0.5 })

    --local sz = self.element.layout.userData.getInnerSize()
end

return IngredientWindow
