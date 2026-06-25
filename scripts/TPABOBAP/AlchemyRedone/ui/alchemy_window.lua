---@omw-context player

local core = require("openmw.core")
local ui = require("openmw.ui")
local util = require("openmw.util")
local auxUi = require('openmw_aux.ui')

local I = require("openmw.interfaces")
local T = require("scripts.UIToolkit.templates")
local H = require("scripts.UIToolkit.helpers")

local Window = require("scripts.UIToolkit.window")

local MWUI = I.MWUI.templates
local v2 = util.vector2

---@class AlchemyWindow: Window
---@field private data openmw.ui.Element?
local AlchemyWindow = Window:new()

function AlchemyWindow:init(data)
    local content = ui.content {}
    self.data = data
    self.element = T.window(core.getGMST('sSkillAlchemy'), content, self.ctx, { draggable = true })
    self:setDimensions({ x = 0.25, y = 0.25, w = 0.5, h = 0.3 })
end

function AlchemyWindow:destroy()
    self.data = nil
    Window.destroy(self)
end

return AlchemyWindow
