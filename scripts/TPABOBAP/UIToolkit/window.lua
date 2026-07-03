---@omw-context player

local ui = require("openmw.ui")
local util = require("openmw.util")
local auxUi = require('openmw_aux.ui')

local H = require("scripts.TPABOBAP.UIToolkit.helpers")

local v2 = util.vector2


---@class WindowContext
---@field updateQueue table<openmw.ui.Element, boolean>
---@field focusedInteractiveDelayed openmw.ui.Element?
---@field focusedInteractive openmw.ui.Element?
---@field focusedScrollable openmw.ui.Element?
---@field activeTooltip openmw.ui.Element?

---@class Window
---@field protected element openmw.ui.Element?
---@field protected ctx WindowContext
local Window = {}

function Window:new()
    local o = setmetatable({}, self)
    self.__index = self
    return o
end

---@param ctx WindowContext
function Window:setContext(ctx)
    self.ctx = ctx
end

function Window:update(deep)
    if not self.element then return end
    if deep then
        auxUi.deepUpdate(self.element)
    else
        self.element:update()
    end
end

function Window:isVisible()
    if not self.element then return false end

    return self.element.layout.props.visible
end

function Window:setVisible(visible)
    if not self.element then return end

    self.element.layout.props.visible = visible
    self:update()
end

function Window:isPinnable()
    if not self.element then return false end

    return self.element.layout.userData.pinnable
end

function Window:isPinned()
    if not self.element then return false end

    return self.element.layout.userData.pinned
end

function Window:isFocused()
    if not self.element then return false end

    return self.element.layout.userData.focused
end

function Window:setFocused(focused)
    if not self.element then return end

    self.element.layout.userData.focused = focused
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

function Window:setSize(size)
    if not self.element then return end
    self.element.layout.props.size = size
    self:update()
end

-- Stub methods to be overridden
function Window:saveState() end

function Window:loadState() end

function Window:onControllerButtonPress(id) end

function Window:destroy()
    self:saveState()
    auxUi.deepDestroy(self.element)
    self.element = nil
    self.ctx = nil
end

return Window
