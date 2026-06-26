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

local MWUI = I.MWUI.templates
local v2 = util.vector2

local ApparatusTypes = types.Apparatus.TYPE

---@class AlchemyWindow: Window
---@field private data table?
local AlchemyWindow = Window:new()

---@return AlchemyWindow
function AlchemyWindow:new()
    local r = Window.new(self)
    ---@cast r AlchemyWindow
    return r
end

local parts = {}

local Slots = { 'First', 'Second', 'Third', 'Fourth' }

local ICON_SZ
local GAP_END
local GAP_MID
local GAP_ICON
local function updateSizes()
    ICON_SZ = util.round(T.TEXT_SIZE * 1.5)
    GAP_ICON = 3
    GAP_END = util.round((ICON_SZ - T.TEXT_SIZE) / 2)
    GAP_MID = 2 * GAP_END + GAP_ICON
end

updateSizes()

---@param ctx AlchemyContext
function AlchemyWindow:init(ctx)
    self:setContext(ctx)
    self.data = ctx.data
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
                        parts.naming(),
                        T.intervalV(15),
                        parts.tools(),
                        T.intervalV(15),
                        parts.selected(),
                    }
                },
            }
        },
    }
    self.ctx.minWidth = 200
    self.ctx.minHeight = 100
    self.element = T.window(core.getGMST('sSkillAlchemy'), content, self.ctx, { draggable = true })
    self:setDimensions({ x = 0.15, y = 0.25, w = 0.4, h = 0.3 })
end

function AlchemyWindow:update(deep)
    if not self.element then return end
    updateSizes()
    local main = H.findByPath(self.element, { 'foreground', 'body', 'main' })

    local tools = H.findByPath(main, { 'left', 'tools-box', 'padding', 'tools' })
    local function updateTool(name, type)
        local record = self:getToolRecord(type)
        local layout = H.findByPath(tools, { 'name', name })
        layout.props.text = record and record.name or C.Strings.NONE

        layout = H.findByPath(tools, { 'quality', name })
        layout.props.text = record and 'x' .. record.quality or ''

        layout = H.findByPath(tools, { 'icon', name })
        layout.props.resource = record and T.createTexture(record.icon)
    end

    updateTool(C.Strings.MORTAR, ApparatusTypes.MortarPestle)
    updateTool(C.Strings.ALEMBIC, ApparatusTypes.Alembic)
    updateTool(C.Strings.CALCINATOR, ApparatusTypes.Calcinator)
    updateTool(C.Strings.RETORT, ApparatusTypes.Retort)

    local selected = H.findByPath(main, { 'left', 'selected-box', 'padding', 'selected' })
    local function updateSelected(n)
        local record, amount = self:getSelectedIngredientRecord(n)
        local name = H.findByPath(selected, { 'name', Slots[n] })
        local icon = H.findByPath(selected, { 'icon', Slots[n] })
        local count = H.findByPath(selected, { 'count', Slots[n] })

        if record and amount > 0 then
            local effects = record.effects
            name.props.text = record.name
            icon.props.resource = T.createTexture(record.icon)
            count.props.text = H.addSeparators(amount)
            for i = 1, 4 do
                icon = H.findByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
                if #effects >= i then
                    --TODO: account for unknown effects
                    icon.props.resource = T.createTexture(core.magic.effects.records[effects[i].id].icon)
                    icon.props.alpha = i == 1 and 1 or 0.5 --TODO: decide alpha based on active affects of a potion
                else
                    icon.props.resource = nil
                end
            end
        else
            name.props.text = C.Strings.NONE
            icon.props.resource = nil
            count.props.text = ''

            for i = 1, 4 do
                icon = H.findByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
                icon.props.resource = nil
            end
        end
    end
    for i = 1, #Slots do
        updateSelected(i)
    end

    Window.update(self, deep)
end

---@param type number
---@return openmw.types.ApparatusRecord?
function AlchemyWindow:getToolRecord(type)
    ---@type LocalApparatusIds?
    local apparatus = self.data and self.data.apparatus
    if not apparatus then return nil end
    if type == ApparatusTypes.MortarPestle then
        return apparatus.Mortar and types.Apparatus.records[apparatus.Mortar]
    elseif type == ApparatusTypes.Calcinator then
        return apparatus.Calcinator and types.Apparatus.records[apparatus.Calcinator]
    elseif type == ApparatusTypes.Alembic then
        return apparatus.Alembic and types.Apparatus.records[apparatus.Alembic]
    elseif type == ApparatusTypes.Retort then
        return apparatus.Retort and types.Apparatus.records[apparatus.Retort]
    end
    return nil
end

---@param n number
---@return openmw.types.IngredientRecord?, number
function AlchemyWindow:getSelectedIngredientRecord(n)
    --TODO: get actual selected ingredients from data
    if n == 1 then
        return types.Ingredient.records['ingred_wickwheat_01'], 10
    end
    if n == 2 then
        return types.Ingredient.records['ingred_marshmerrow_01'], 100
    end
    return nil, 0
end

function AlchemyWindow:destroy()
    self.data = nil
    Window.destroy(self)
end

parts.naming = function()
    return {
        name = 'naming',
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
            --gap = 10, --TODO: this is not in 0.51, hope for 0.52
            arrange = ui.ALIGNMENT.Center,
        },
        content = ui.content {
            {
                template = T.textNormal,
                props = {
                    text = 'Name',
                },
            },
            T.intervalH(10),
            {
                name = 'searchBar',
                template = I.MWUI.templates.box,
                content = ui.content {
                    {
                        name = 'padding',
                        template = I.MWUI.templates.padding,
                        content = ui.content {
                            {
                                name = 'textEdit',
                                template = T.textEditLine,
                                props = {
                                    size = v2(300, 16),
                                    text = '',
                                    textColor = C.Colors.DEFAULT_LIGHT,
                                },
                                events = {
                                    textChanged = async:callback(function(text, layout)
                                    end),
                                    focusGain = async:callback(function(_, layout)
                                    end),
                                    focusLoss = async:callback(function(_, layout)
                                    end),
                                }
                            }
                        }
                    }
                },
            },
        }
    }
end

parts.tools = function()
    return {
        name = 'tools-box',
        template = T.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.padding(5),
                content = ui.content {
                    {
                        name = 'tools',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start,
                        },
                        content = ui.content {
                            {
                                name = 'title',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.End,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedTitle(C.Strings.MORTAR),
                                    T.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.ALEMBIC),
                                    T.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.CALCINATOR),
                                    T.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.RETORT),
                                    T.intervalV(GAP_END),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(C.Strings.MORTAR, ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.ALEMBIC, ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.CALCINATOR, ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.RETORT, ICON_SZ),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedHeader(C.Strings.MORTAR),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.ALEMBIC),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.CALCINATOR),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.RETORT),
                                    T.intervalV(GAP_END),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'quality',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedText(C.Strings.MORTAR),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.ALEMBIC),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.CALCINATOR),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.RETORT),
                                    T.intervalV(GAP_END),
                                }
                            },
                        },
                    }
                },
            }
        }
    }
end

parts.selected = function()
    return {
        name = 'selected-box',
        template = T.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.padding(5),
                content = ui.content {
                    {
                        name = 'selected',
                        type = ui.TYPE.Flex,
                        props = {
                            horizontal = true,
                            arrange = ui.ALIGNMENT.Start,
                        },
                        content = ui.content {

                            {
                                name = 'count',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.End,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedText(Slots[1]),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(Slots[2]),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(Slots[3]),
                                    T.intervalV(GAP_MID),
                                    parts.namedText(Slots[4]),
                                    T.intervalV(GAP_END),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(Slots[1], ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[2], ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[3], ICON_SZ),
                                    T.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[4], ICON_SZ),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedHeader(Slots[1]),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[2]),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[3]),
                                    T.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[4]),
                                    T.intervalV(GAP_END),
                                }
                            },
                            T.intervalH(10),
                            {
                                name = 'effects',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.intervalV(GAP_END),
                                    parts.namedEffects(Slots[1]),
                                    T.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[2]),
                                    T.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[3]),
                                    T.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[4]),
                                    T.intervalV(GAP_END),
                                }
                            },
                        },
                    }
                },
            }
        }
    }
end

parts.namedTitle = function(name)
    return {
        name = name,
        template = T.textNormal,
        props = {
            text = name .. ':',
        },
    }
end

parts.namedHeader = function(name)
    return {
        name     = name,
        template = T.textHeader,
        props    = {
            text = '',
        },
    }
end

parts.namedText = function(name)
    return {
        name = name,
        template = T.textNormal,
        props = {
            text = '',
        },
    }
end

parts.namedIcon = function(name, sz)
    sz = sz or T.TEXT_SIZE
    return {
        name = name,
        type = ui.TYPE.Image,
        props = {
            size = v2(sz, sz),
        },
    }
end

parts.effectIcon = function(idx)
    return parts.namedIcon('effect_' .. idx)
end

parts.namedEffects = function(name)
    return {
        name = name,
        type = ui.TYPE.Flex,
        props = {
            horizontal = true,
        },
        content = ui.content {
            parts.effectIcon(1),
            T.intervalH(5),
            parts.effectIcon(2),
            T.intervalH(5),
            parts.effectIcon(3),
            T.intervalH(5),
            parts.effectIcon(4),
        },
    }
end

return AlchemyWindow
