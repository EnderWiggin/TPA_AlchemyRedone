---@omw-context player

local ui = require('openmw.ui')
local auxUi = require('openmw_aux.ui')
local util = require('openmw.util')
local core = require('openmw.core')
local I = require('openmw.interfaces')
local types = require('openmw.types')
local async = require('openmw.async')
local ambient = require('openmw.ambient')

local v2 = util.vector2
local BASE = require('scripts.UIToolkit.templates.base')
local helpers = require('scripts.UIToolkit.helpers')

local Templates = {}

local lastMousePos = nil


---@param props any
---@param element openmw.ui.Element|openmw.ui.Layout
---@param ctx any
---@return any
Templates.interactive = function(props, element, ctx)
    local function absToRel(absPos)
        local layerSize = ui.layers[ui.layers.indexOf('Notification')].size
        return v2(
            absPos.x / layerSize.x,
            absPos.y / layerSize.y
        )
    end

    local function createTooltip()
        if not props.tooltipFn then return nil end

        if ctx.modalElement then
            return nil
        end

        local tip = props.tooltipFn()
        if not tip then return end
        ctx.activeTooltip = ui.create(tip)
        ctx.activeTooltip.layout.name = props.name
        if lastMousePos then
            ctx.activeTooltip.layout.props.anchor = v2(absToRel(lastMousePos).x, 0)
            ctx.activeTooltip.layout.props.position = v2(lastMousePos.x, lastMousePos.y + 32)
        end
        ctx.activeTooltip:update()
        return ctx.activeTooltip
    end

    element = element.layout and element or ui.create(element)
    if props.name then
        element.layout.name = props.name
    end

    element.layout.userData = element.layout.userData or {}
    element.layout.userData.interactive = true

    element.layout.events = element.layout.events or {}
    element.layout.events.mousePress = async:callback(function(e, layout)
        if e.button ~= 1 then
            return false
        end
        if props.onClick then
            if props.canClick and not props.canClick() then
                return false
            end
            element.layout.userData.pressed = true
            ambient.playSound('menu click')
            helpers.setInteractiveColor(element.layout)
            element:update()

            if props.parent then
                ctx.updateQueue[props.parent] = true
            end
            return true
        end
        return false
    end)
    element.layout.events.mouseRelease = async:callback(function(e, layout)
        if e.button ~= 1 then
            return false
        end
        if props.onClick then
            if not element.layout.userData.pressed then
                return false
            end
            element.layout.userData.pressed = false
            helpers.setInteractiveColor(element.layout)
            local result = props.onClick()
            element:update()

            if ctx.activeTooltip and ctx.activeTooltip.layout and ctx.activeTooltip.layout.name == props.name then
                auxUi.deepDestroy(ctx.activeTooltip)
                ctx.activeTooltip = createTooltip()
            end

            if props.parent then
                ctx.updateQueue[props.parent] = true
            end
            return result
        end
        return false
    end)
    element.layout.events.focusLoss = async:callback(function()
        ctx.focusedInteractiveDelayed = false
        element.layout.userData.hovering = false
        if props.tooltipFn then
            if ctx.activeTooltip and ctx.activeTooltip.layout then
                ctx.activeTooltip.layout.props.visible = false
                ctx.updateQueue[ctx.activeTooltip] = true
            end
        end

        if props.onClick then
            helpers.setInteractiveColor(element.layout)
            ctx.updateQueue[element] = true

            if props.parent then
                ctx.updateQueue[props.parent] = true
            end
        end
        return true
    end)
    element.layout.events.focusGain = async:callback(function()
        ctx.focusedInteractiveDelayed = element
        if props.onClick then
            helpers.setInteractiveColor(element.layout)
            ctx.updateQueue[element] = true

            if props.parent then
                ctx.updateQueue[props.parent] = true
            end
        end
        return true
    end)
    element.layout.events.mouseMove = async:callback(function(e, tgt)
        if props.onMouseMove then
            props.onMouseMove(e, tgt, element)
        end
        element.layout.userData.hovering = true
        if props.tooltipFn then
            if not ctx.activeTooltip or not ctx.activeTooltip.layout then
                ctx.activeTooltip = createTooltip()
            elseif ctx.activeTooltip.layout.name ~= props.name then
                auxUi.deepDestroy(ctx.activeTooltip)
                ctx.activeTooltip = createTooltip()
            end
            if ctx.activeTooltip then
                ctx.activeTooltip.layout.props.visible = true
                local distToBottom = ui.layers[ui.layers.indexOf('Notification')].size.y - (e.position.y - e.offset.y)
                if distToBottom < ui.layers[ui.layers.indexOf('Notification')].size.y / 2 then
                    ctx.activeTooltip.layout.props.anchor = v2(absToRel(e.position).x, 1)
                    ctx.activeTooltip.layout.props.position = v2(e.position.x, e.position.y - 32)
                else
                    ctx.activeTooltip.layout.props.anchor = v2(absToRel(e.position).x, 0)
                    ctx.activeTooltip.layout.props.position = v2(e.position.x, e.position.y + 32)
                end
                ctx.activeTooltip:update()
                lastMousePos = e.position
            end
        end
        return true
    end)
    return element
end

Templates.tooltip = function(padding, content, name)
    return {
        layer = 'Notification',
        name = name,
        template = BASE.boxSolid,
        props = {
        },
        content = ui.content {
            {
                name = 'padding',
                template = BASE.padding(padding),
                content = content or ui.content {},
            }
        }
    }
end

Templates.lineTooltip = function(text, name)
    return Templates.tooltip(4, ui.content {
        {
            template = BASE.textNormal,
            props = {
                text = text or '',
                autoSize = true,
            }
        }
    }, name)
end


return Templates
