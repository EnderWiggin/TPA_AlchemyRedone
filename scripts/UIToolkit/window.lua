---@omw-context player

local ui = require("openmw.ui")
local util = require("openmw.util")
local auxUi = require('openmw_aux.ui')

local H = require("scripts.UIToolkit.helpers")

local v2 = util.vector2

---@class Window
---@field protected element openmw.ui.Element?
---@field protected ctx table
local Window = {
    ctx = {},
}

---@function
---@param o? Window
function Window:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Window:update(deep)
    if not self.element then return end
    if deep then
        auxUi.deepUpdate(self.element)
    else
        self.element:update()
    end
end

function Window:getDimensions()
    if not self.element then return nil end

    local layerSize = ui.layers[ui.layers.indexOf('Windows')].size

    local props = self.element.layout.props
    if not props or not props.position or not props.size then return nil end
    return {
        x = H.roundToPlaces(props.position.x / layerSize.x, 6),
        y = H.roundToPlaces(props.position.y / layerSize.y, 6),
        w = H.roundToPlaces(props.size.x / layerSize.x, 6),
        h = H.roundToPlaces(props.size.y / layerSize.y, 6),
    }
end

function Window:setDimensions(dimensions)
    if not self.element then return end

    local layerSize = ui.layers[ui.layers.indexOf('Windows')].size

    self.element.layout.props.position = v2(dimensions.x * layerSize.x, dimensions.y * layerSize.y)
    self.element.layout.props.size = v2(dimensions.w * layerSize.x, dimensions.h * layerSize.y)
    self:update()
end

function Window:destroy()
    auxUi.deepDestroy(self.element)
    self.element = nil
    self.ctx = nil
end

return Window
