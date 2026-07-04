---@omw-context menu

local core = require('openmw.core')
local ui = require('openmw.ui')
local async = require('openmw.async')
local util = require('openmw.util')
local input = require('openmw.input')
local I = require('openmw.interfaces')

local function paddedBox(layout)
    return {
        template = I.MWUI.templates.box,
        content = ui.content {
            {
                template = I.MWUI.templates.padding,
                content = ui.content { layout },
            },
        }
    }
end

local controllerButtonNames = {
    [input.CONTROLLER_BUTTON.A] = "A",
    [input.CONTROLLER_BUTTON.B] = "B",
    [input.CONTROLLER_BUTTON.X] = "X",
    [input.CONTROLLER_BUTTON.Y] = "Y",
    [input.CONTROLLER_BUTTON.Back] = "Back",
    [input.CONTROLLER_BUTTON.Guide] = "Guide",
    [input.CONTROLLER_BUTTON.Start] = "Start",
    [input.CONTROLLER_BUTTON.LeftStick] = "Left Stick",
    [input.CONTROLLER_BUTTON.RightStick] = "Right Stick",
    [input.CONTROLLER_BUTTON.LeftShoulder] = "LB",
    [input.CONTROLLER_BUTTON.RightShoulder] = "RB",
    [input.CONTROLLER_BUTTON.DPadUp] = "D-pad Up",
    [input.CONTROLLER_BUTTON.DPadDown] = "D-pad Down",
    [input.CONTROLLER_BUTTON.DPadLeft] = "D-pad Left",
    [input.CONTROLLER_BUTTON.DPadRight] = "D-pad Right",
}

local function nameButton(id)
    if not id then return core.getGMST('sNone') end

    return controllerButtonNames[id] or tostring(id)
end

local recording

local function renderer(value, set, _)
    local element

    ---@param name string
    local function setName(name)
        element.layout.props.text = name
        element:update()
    end

    element = ui.create {
        template = I.MWUI.templates.textNormal,
        props = {
            text = '',
            textAlignH = ui.ALIGNMENT.Center,
            textAlignV = ui.ALIGNMENT.Center,
            autoSize = false,
            size = util.vector2(100, I.MWUI.templates.textNormal.props.textSize),
        },
        events = {
            mouseClick = async:callback(function()
                if recording ~= nil then return end
                setName('...')
                recording = function(id)
                    setName(nameButton(id))
                    if id ~= value then
                        set(id)
                    end
                    recording = nil
                end
            end),
        },
    }
    setName(nameButton(value))
    return paddedBox(element)
end

return {
    renderer = renderer,
    handlers = {
        onKeyPress = function(key)
            if recording and (key.code == input.KEY.Escape or key.code == input.KEY.Backspace) then
                recording(nil)
            end
        end,
        onControllerButtonPress = function(id)
            if recording then recording(id) end
        end,
    }
}
