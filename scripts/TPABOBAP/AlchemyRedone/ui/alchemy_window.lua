---@omw-context player

local core = require("openmw.core")
local ui = require("openmw.ui")
local util = require("openmw.util")
local types = require("openmw.types")
local async = require('openmw.async')
local player = require('openmw.self')

local I = require("openmw.interfaces")
local T = {
    Base = require("scripts.UIToolkit.templates.base"),
    Special = require("scripts.UIToolkit.templates.special"),
}
local S = require("scripts.UIToolkit.templates.special")
local C = require("scripts.UIToolkit.constants")
local H = require("scripts.UIToolkit.helpers")
local A = require("scripts.TPABOBAP.AlchemyRedone.alchemy")

local Window = require("scripts.UIToolkit.window")

local MWUI = I.MWUI.templates
local v2 = util.vector2

local ApparatusTypes = types.Apparatus.TYPE

---@class AlchemyWindow: Window
---@field protected ctx AlchemyContext
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
    ICON_SZ = util.round(T.Base.TEXT_SIZE * 1.5)
    GAP_ICON = 3
    GAP_END = util.round((ICON_SZ - T.Base.TEXT_SIZE) / 2)
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
                T.Base.intervalH(5),
                {
                    name = 'left',
                    type = ui.TYPE.Flex,
                    props = {},
                    content = ui.content {
                        parts.naming(),
                        T.Base.intervalV(15),
                        parts.tools(),
                        T.Base.intervalV(15),
                        parts.selected(ctx,
                            function(n)
                                local r = self:getSelectedIngredientRecord(n)
                                return r and r.id
                            end,
                            function(n)
                                self:onIngredientClicked(n)
                            end,
                            function(n)
                                return self:makeIngredientTip(n)
                            end),
                    }
                },
            }
        },
    }
    self.ctx.minWidth = 200
    self.ctx.minHeight = 100
    self.element = T.Base.window(core.getGMST('sSkillAlchemy'), content, self.ctx, { draggable = true })
    self:setDimensions({ x = 0.15, y = 0.25, w = 0.4, h = 0.3 })
end

function AlchemyWindow:update(deep)
    if not self.element then return end
    updateSizes()
    self:updateMatchingEffects()
    local main = H.findLayoutByPath(self.element, { 'foreground', 'body', 'main' })

    local tools = H.findLayoutByPath(main, { 'left', 'tools-box', 'padding', 'tools' })
    local function updateTool(name, type)
        local record = self:getToolRecord(type)
        local layout = H.findLayoutByPath(tools, { 'name', name })
        layout.props.text = record and record.name or C.Strings.NONE

        layout = H.findLayoutByPath(tools, { 'quality', name })
        layout.props.text = record and 'x' .. record.quality or ''

        layout = H.findLayoutByPath(tools, { 'icon', name })
        layout.props.resource = record and T.Base.createTexture(record.icon)
    end

    updateTool(C.Strings.MORTAR, ApparatusTypes.MortarPestle)
    updateTool(C.Strings.ALEMBIC, ApparatusTypes.Alembic)
    updateTool(C.Strings.CALCINATOR, ApparatusTypes.Calcinator)
    updateTool(C.Strings.RETORT, ApparatusTypes.Retort)

    local selected = H.findLayoutByPath(main, { 'left', 'selected-box', 'padding', 'selected' })
    local function updateSelected(n)
        local record, amount = self:getSelectedIngredientRecord(n)
        local name = H.findLayoutByPath(selected, { 'name', Slots[n] })
        local icon = H.findLayoutByPath(selected, { 'icon', Slots[n] })
        local count = H.findLayoutByPath(selected, { 'count', Slots[n] })

        if record and amount > 0 then
            local effects = record.effects
            name.props.text = record.name
            icon.props.resource = T.Base.createTexture(record.icon)
            count.props.text = H.addSeparators(amount)
            local known = A.getKnownEffectFlagsForIngredient(record, player)
            for i = 1, 4 do
                icon = H.findLayoutByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
                if #effects >= i then
                    local effect = effects[i]
                    if known[i] then
                        icon.props.resource = T.Base.effectIconTexture(effect.id)
                    else
                        icon.props.resource = T.Special.TEX.UNKNOWN_EFFECT
                    end
                    icon.props.alpha = A.containsEffect(self.data.matching, effect) and 1 or 0.5
                else
                    icon.props.resource = nil
                end
            end
        else
            name.props.text = C.Strings.NONE
            icon.props.resource = nil
            count.props.text = ''

            for i = 1, 4 do
                icon = H.findLayoutByPath(selected, { 'effects', Slots[n], 'effect_' .. i })
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
    if self.data and self.data.selected then
        local info = self.data.selected[n]
        if info then
            return types.Ingredient.records[info.id], info.count
        end
    end
    return nil, 0
end

function AlchemyWindow:makeIngredientTip(n)
    if not self.data or not self.data.selected then return nil end
    print('makeIngredientTip', n, self.data.selected[n])
    if self.data.selected[n] then
        return T.Special.ingredientTooltip(self.data.selected[n].id, player)
    end
    return nil
end

function AlchemyWindow:onIngredientClicked(n)
    if self.data and self.data.selected then
        self.data.selected[n] = nil
        self:update()
        self.ctx.updateIngredients(true)
    end
end

function AlchemyWindow:onSelectIngredient(info)
    if not self.data then self.data = {} end
    if not self.data.selected then self.data.selected = {} end

    --Try to remove already selected ingredient
    for i = 1, 4 do
        local item = self.data.selected[i]
        if item and item.id == info.id then
            self.data.selected[i] = nil
            self:update()
            return true
        end
    end

    --Try to add newly selected ingredient
    for i = 1, 4 do
        if not self.data.selected[i] then
            self.data.selected[i] = info
            self:update(true)
            return true
        end
    end

    return false
end

function AlchemyWindow:updateMatchingEffects()
    local ids = {}
    local selected = self.data.selected
    if selected then
        for i = 1, 4 do
            if selected[i] and selected[i].id then
                table.insert(ids, selected[i].id)
            end
        end
    end

    self.data.matching = A.getMatchingEffects(ids)
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
                template = T.Base.textNormal,
                props = {
                    text = 'Name',
                },
            },
            T.Base.intervalH(10),
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
                                template = T.Base.textEditLine,
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
        template = T.Base.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.Base.padding(5),
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
                                    T.Base.intervalV(GAP_END),
                                    parts.namedTitle(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedTitle(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(C.Strings.MORTAR, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.ALEMBIC, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.CALCINATOR, ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(C.Strings.RETORT, ICON_SZ),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedHeader(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'quality',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedText(C.Strings.MORTAR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.ALEMBIC),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.CALCINATOR),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(C.Strings.RETORT),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                        },
                    }
                },
            }
        }
    }
end

parts.selected = function(ctx, getId, onClick, tooltipFn)
    return {
        name = 'selected-box',
        template = T.Base.boxSolid,
        content = ui.content {
            {
                name = 'padding',
                template = T.Base.padding(5),
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
                                    T.Base.intervalV(GAP_END),
                                    parts.namedText(Slots[1]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(Slots[2]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(Slots[3]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedText(Slots[4]),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'icon',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Center,
                                },
                                content = ui.content {
                                    parts.namedIcon(Slots[1], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[2], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[3], ICON_SZ),
                                    T.Base.intervalV(GAP_ICON),
                                    parts.namedIcon(Slots[4], ICON_SZ),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'name',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedHeader(Slots[1], ctx,
                                        function() return getId(1) end,
                                        function() onClick(1) end,
                                        function() return tooltipFn(1) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[2], ctx,
                                        function() return getId(2) end,
                                        function() onClick(2) end,
                                        function() return tooltipFn(2) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[3], ctx,
                                        function() return getId(3) end,
                                        function() onClick(3) end,
                                        function() return tooltipFn(3) end),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedHeader(Slots[4], ctx,
                                        function() return getId(4) end,
                                        function() onClick(4) end,
                                        function() return tooltipFn(4) end),
                                    T.Base.intervalV(GAP_END),
                                }
                            },
                            T.Base.intervalH(10),
                            {
                                name = 'effects',
                                type = ui.TYPE.Flex,
                                props = {
                                    horizontal = false,
                                    arrange = ui.ALIGNMENT.Start,
                                },
                                content = ui.content {
                                    T.Base.intervalV(GAP_END),
                                    parts.namedEffects(Slots[1]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[2]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[3]),
                                    T.Base.intervalV(GAP_MID),
                                    parts.namedEffects(Slots[4]),
                                    T.Base.intervalV(GAP_END),
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
        template = T.Base.textNormal,
        props = {
            text = name .. ':',
        },
    }
end

parts.namedHeader = function(name, ctx, getId, onClick, tooltipFn)
    local layout = {
        name     = name,
        template = T.Base.textHeader,
        props    = {
            text = '',
        },
    }
    if not ctx then return layout end

    return S.interactive({
        onClick = onClick,
        tooltipFn = tooltipFn,
        name = getId and getId() or name
    }, layout, ctx)
end

parts.namedText = function(name)
    return {
        name = name,
        template = T.Base.textNormal,
        props = {
            text = '',
        },
    }
end

parts.namedIcon = function(name, sz)
    sz = sz or T.Base.TEXT_SIZE
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
            T.Base.intervalH(5),
            parts.effectIcon(2),
            T.Base.intervalH(5),
            parts.effectIcon(3),
            T.Base.intervalH(5),
            parts.effectIcon(4),
        },
    }
end

return AlchemyWindow
