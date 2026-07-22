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
local BASE = require('scripts.TPABOBAP.UIToolkit.templates.base')
local helpers = require('scripts.TPABOBAP.UIToolkit.helpers')
local constants = require('scripts.TPABOBAP.UIToolkit.constants')

local Templates = {}

local lastMousePos = nil

Templates.TEX = {
    UNKNOWN_EFFECT = BASE.createTexture('icons/TPABOBAP/AlchemyRedone/unknown-effect.png')
}

---@class InteractiveProps
---@field name string sets name for the element
---@field tooltipFn? fun():openmw.ui.Layout optional function to get tooltip layout
---@field onClick? fun() optional function to be called when element is clicked. Note: element won't change colors if there's no click callback set
---@field canClick? fun():boolean
---@field parent? any parent element? not sure
---@field onMouseMove? fun(e, tgt, element)

---@param props InteractiveProps
---@param element openmw.ui.Element|openmw.ui.Layout
---@param ctx WindowContext
---@return any
Templates.interactive = function(props, element, ctx)
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
            ctx.activeTooltip.layout.props.anchor = v2(0, 0)
            ctx.activeTooltip.layout.props.position = v2(lastMousePos.x, lastMousePos.y + 32)
        end
        ctx.activeTooltip:update()
        return ctx.activeTooltip
    end

    element = element.layout and element or ui.create(element)
    ---@cast element openmw.ui.Element

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
        if props.tooltipFn then
            if ctx.activeTooltip and ctx.activeTooltip.layout then
                ctx.activeTooltip.layout.props.visible = false
                ctx.updateQueue[ctx.activeTooltip] = true
            end
        end

        if props.onClick then
            ctx.setHovered(nil)

            if props.parent then
                ctx.updateQueue[props.parent] = true
            end
        end
        return true
    end)
    element.layout.events.focusGain = async:callback(function()
        if props.onClick then
            ctx.focusedInteractiveDelayed = element
            ctx.setHovered(element)

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
        ctx.setHovered(element)
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
                -- anchor left so the tooltip opens rightward, never over the hovered list; y still flips up near the bottom edge
                if distToBottom < ui.layers[ui.layers.indexOf('Notification')].size.y / 2 then
                    ctx.activeTooltip.layout.props.anchor = v2(0, 1)
                    ctx.activeTooltip.layout.props.position = v2(e.position.x, e.position.y - 32)
                else
                    ctx.activeTooltip.layout.props.anchor = v2(0, 0)
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

---@param text string
---@param opts InteractiveProps
---@param ctx WindowContext
---@return openmw.ui.Element
Templates.button = function(text, opts, ctx)
    local base = {
        name = opts.name,
        template = BASE.buttonBoxBgr(0.5),
        props = {},
        content = ui.content {
            {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = ui.content {
                    BASE.intervalH(8),
                    {
                        template = BASE.textNormal,
                        props = {
                            text = text,
                            textColor = constants.Colors.DEFAULT,
                        },
                        userData = { colorable = true },
                    },
                    BASE.intervalH(8),
                }
            }
        },
        events = {},
        userData = {},
    }

    return Templates.interactive(opts, base, ctx)
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

Templates.lineTooltip = function(text, name, props)
    return Templates.tooltip(4, ui.content {
        {
            template = BASE.textNormal,
            props = helpers.mergeTables({
                text = text or '',
                autoSize = true,
                multiline = true,
            }, props or {})
        }
    }, name)
end

---@param text string
---@param name string?
---@param props table?
---@return openmw.ui.Layout
Templates.paragraphTooltip = function(text, name, props)
    return Templates.tooltip(4, ui.content {
        {
            template = BASE.textParagraph,
            props = helpers.mergeTables({
                text = text,
                textAlignH = ui.ALIGNMENT.Start,
                size = v2(300, 0),
            }, props or {})
        },
    }, name)
end

---@param id string
---@param actor openmw.GObject|openmw.LObject|nil
Templates.ingredientTooltip = function(id, actor)
    local itemRecord = types.Ingredient.record(id)
    if not itemRecord then return nil end

    local function textNormal(name, text)
        return { name = name, template = BASE.textNormal, props = { text = text } }
    end
    local function textHeader(name, text)
        return { name = name, template = BASE.textHeader, props = { text = text } }
    end

    local nameString = itemRecord.name

    local innerContent = ui.content {}

    innerContent:add(textHeader('name', nameString))


    innerContent:add(BASE.intervalV(4))


    -- Handle effects for enchantments, potions, and ingredients.
    local effectsToShow = helpers.getTooltipIngredientEffectEntries(itemRecord, actor)

    -- Build effect layouts if we have any effects
    if #effectsToShow > 0 then
        local effectLayouts = {}
        for i, effectData in ipairs(effectsToShow) do
            local effect = effectData.effect
            local isVisible = effectData.visible
            local content = ui.content {}

            if isVisible then
                content:add(Templates.effectIcon(effect.id))
                content:add(BASE.intervalH(4))
                local effectText = effectData.text or '?'
                content:add(textNormal('effect_' .. i, effectText))
            else
                content:add(textNormal('effect_' .. i, '?'))
            end

            local effectLayout = {
                type = ui.TYPE.Flex,
                props = {
                    horizontal = true,
                    arrange = ui.ALIGNMENT.Center,
                },
                content = content,
            }

            if i ~= 1 then
                table.insert(effectLayouts, BASE.intervalV(8))
            end
            table.insert(effectLayouts, effectLayout)
        end

        innerContent:add(BASE.intervalV(4))
        innerContent:add({
            name = 'effects',
            type = ui.TYPE.Flex,
            props = {
                arrange = ui.ALIGNMENT.Start,
            },
            content = ui.content {
                table.unpack(effectLayouts)
            }
        })
    end

    local info = Templates.valueWeightInfo(itemRecord.value, itemRecord.weight)
    if info then
        innerContent:add(BASE.intervalV(8))
        innerContent:add(info)
    end

    if #innerContent == 2 then
        innerContent[2] = nil -- remove extra interval if no details
    end

    local layout = Templates.tooltip(8, ui.content {
        {
            name = 'tooltip',
            type = ui.TYPE.Flex,
            props = {
                align = ui.ALIGNMENT.Center,
                arrange = ui.ALIGNMENT.Center,
            },
            content = innerContent,
        }
    }, id)

    return layout
end

---@param value number
---@param weight number
---@return openmw.ui.Layout|nil
Templates.valueWeightInfo = function(value, weight)
    local flexContent = ui.content {}
    value = util.round(value)
    if value > 0 then
        flexContent:add({
            type = ui.TYPE.Image,
            props = {
                size = v2(1, 1) * BASE.TEXT_SIZE,
                resource = BASE.createTexture('icons/gold.dds'),
            }
        })
        flexContent:add({ name = 'value', template = BASE.textNormal, props = { text = ' ' .. helpers.addSeparators(value) } })
    end

    weight = helpers.roundToPlaces(weight, 2)
    if weight > 0 then
        if #flexContent > 0 then
            flexContent:add(BASE.intervalH(8))
        end
        flexContent:add({
            type = ui.TYPE.Image,
            props = {
                size = v2(1, 1) * BASE.TEXT_SIZE,
                resource = BASE.createTexture('icons/weight.dds'),
            }
        })
        flexContent:add({ name = 'weight', template = BASE.textNormal, props = { text = ' ' .. helpers.addSeparators(weight) } })
    end

    if #flexContent > 0 then
        return {
            name = 'info',
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                align = ui.ALIGNMENT.End,
                arrange = ui.ALIGNMENT.Center,
            },
            external = {
                stretch = 1,
            },
            content = flexContent
        }
    end
    return nil
end

---@param id string
---@return openmw.ui.Layout
Templates.magicEffectTooltip = function(id)
    return Templates.paragraphTooltip(helpers.getMagicEffectDescription(id), id, { textAlignH = ui.ALIGNMENT.Center })
end

Templates.effectIcon = function(effectId)
    local layout = {
        type = ui.TYPE.Image,
        props = {
            size = v2(1, 1) * BASE.TEXT_SIZE,
            resource = BASE.effectIconTexture(effectId),
        },
    }
    return layout
end


return Templates
