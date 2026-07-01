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

Templates.lineTooltip = function(text, name)
    return Templates.tooltip(4, ui.content {
        {
            template = BASE.textNormal,
            props = {
                text = text or '',
                autoSize = true,
                multiline = true,
            }
        }
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


    if itemRecord.weight > 0 then
        innerContent:add(textNormal('weight',
            constants.Strings.WEIGHT .. ': ' .. helpers.roundToPlaces(itemRecord.weight, 3)))
    end

    local value = itemRecord.value
    if value > 0 and itemRecord.id ~= 'gold_001' then
        innerContent:add(textNormal('value', constants.Strings.VALUE .. ': ' .. (value)))
    end

    -- Handle effects for enchantments, potions, and ingredients.
    local effectsToShow = helpers.getTooltipIngredientEffectEntries(itemRecord, actor)

    -- Build effect layouts if we have any effects
    if #effectsToShow > 0 then
        local effectLayouts = {}
        for i, effectData in ipairs(effectsToShow) do
            local effect = effectData.effect
            local isVisible = effectData.visible ~= false
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
                arrange = ui.ALIGNMENT.Center,
            },
            content = ui.content {
                table.unpack(effectLayouts)
            }
        })
    end

    --[[
    if configPlayer.tweaks.b_CondensedWeightValue then
        if innerContent:indexOf('weight') then
            innerContent.weight = nil
        end
        if innerContent:indexOf('value') then
            innerContent.value = nil
        end

        local flexContent = ui.content {}

        if value > 0 and itemRecord.id ~= 'gold_001' then
            flexContent:add({
                type = ui.TYPE.Image,
                props = {
                    size = v2(16, 16),
                    resource = BASE.createTexture('icons/gold.dds'),
                }
            })
            flexContent:add(textNormal(nil, ' ' .. helpers.addSeparators(util.round(value))))
        end

        if itemRecord.weight > 0 then
            if #flexContent > 0 then
                flexContent:add(BASE.intervalH(4))
            end
            flexContent:add({
                type = ui.TYPE.Image,
                props = {
                    size = v2(16, 16),
                    resource = BASE.createTexture('icons/weight.dds'),
                }
            })
            flexContent:add(textNormal(nil, ' ' .. helpers.roundToPlaces(itemRecord.weight, 2)))
        end

        if #flexContent > 0 then
            local flex = {
                name = 'weightValue',
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
            innerContent:add(BASE.intervalV(8))
            innerContent:add(flex)
        end
    end
    ]]

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

Templates.effectIcon = function(effectId)
    local effectRecord = core.magic.effects.records[effectId] or
        (I.MagicWindow and I.MagicWindow.Spells.getCustomEffect(effectId))
    local layout = {
        type = ui.TYPE.Image,
        props = {
            size = v2(16, 16),
            resource = BASE.createTexture(effectRecord.icon),
        },
    }
    return layout
end


return Templates
